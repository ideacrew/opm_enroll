module Factories
  class FamilyEnrollmentRenewalFactory
    include Mongoid::Document

    attr_accessor :family, :census_employee, :employer, :renewing_plan_year, :disable_notifications, :active_plan_year, :coverage_kind

    def initialize
      @disable_notifications = false
    end

    def renew
      raise ArgumentError unless defined?(family)

      @plan_year_start_on = renewing_plan_year.start_on
      @active_plan_year = employer.plan_years.published_and_expired_plan_years_by_date(@plan_year_start_on.prev_day).first

      ## Works only for data migrated into Enroll
      ## FIXME add logic to support Enroll native renewals

      raise FamilyEnrollmentRenewalFactoryError, 'Active plan year missing' if @active_plan_year.blank?

      HbxEnrollment::COVERAGE_KINDS.each do |kind|
        @coverage_kind = kind

        if employer_offering_coverage_kind?
          generate_renewals
        end
        # trigger_notice_dental(enrollment_id: find_active_coverage.hbx_id.to_s) { "dental_carriers_exiting_shop_notice_to_ee" } if kind == 'dental' && find_active_coverage.present? && has_metlife_or_delta_plan?(find_active_coverage)
      end

      family
    end

    def generate_renewals
      active_enrollment = find_active_coverage

      begin
        if active_enrollment.present?
          renewal_enrollments = find_renewal_enrollments
          passive_renewals = renewal_enrollments.where(:aasm_state.in => HbxEnrollment::RENEWAL_STATUSES + ['renewing_waived'])

          if renewal_enrollments.where(:aasm_state.in => HbxEnrollment::ENROLLED_STATUSES + ['inactive']).present?
            passive_renewals.each{|e| e.cancel_coverage! if e.may_cancel_coverage?}
          else
            if passive_renewals.blank?
              if active_enrollment.present? && active_enrollment.inactive?
                renew_enrollment(enrollment: active_enrollment, waiver: true)
                census_employee.trigger_model_event(:employee_coverage_passively_waived, {event_object: renewing_plan_year}) unless disable_notifications
              elsif renewal_plan_offered_by_er?(active_enrollment)
                renewal_enrollment = renew_enrollment(enrollment: active_enrollment)
                census_employee.trigger_model_event(:employee_coverage_passively_renewed, {event_object: renewing_plan_year}) unless (renewal_enrollment.coverage_kind == "dental" || disable_notifications)
              else
                census_employee.trigger_model_event(:employee_coverage_passive_renewal_failed, {event_object: renewing_plan_year}) unless disable_notifications
              end
            end
          end
        elsif find_renewal_enrollments.blank?
          census_employee.trigger_model_event(:employee_coverage_passively_waived, {event_object: renewing_plan_year}) unless disable_notifications
        end
      rescue Exception => e
        "Error found for #{census_employee.full_name} while creating renewals -- #{e.inspect}" unless Rails.env.test?
      end
    end

    def has_metlife_or_delta_plan?(active_enr)
      carrier_name = active_enr.plan.carrier_profile.legal_name.downcase
      (active_enr.benefit_group.plan_year.start_on < Date.new(2019,1,1)) && carrier_name && (["metlife", "delta dental"].include?(carrier_name))
    end

    def find_active_coverage
      shop_enrollments = family.active_household.hbx_enrollments.shop_market.by_coverage_kind(coverage_kind)
      shop_enrollments = shop_enrollments.where({
        :benefit_group_id.in => @active_plan_year.benefit_groups.pluck(:_id),
        :aasm_state.in => HbxEnrollment::ENROLLED_STATUSES + ['inactive', 'coverage_expired'] - ['coverage_termination_pending']
      })

      shop_enrollments.compact.sort_by{|e| e.submitted_at || e.created_at }.last
    end

    def renewal_plan_offered_by_er?(enrollment)
      plan = enrollment.plan
      if plan.present? || plan.renewal_plan(renewing_plan_year.start_on).present?
        benefit_group = renewal_assignment.try(:benefit_group) || renewing_plan_year.default_benefit_group || renewing_plan_year.benefit_groups.first
        elected_plan_ids = (enrollment.coverage_kind == 'health' ? benefit_group.elected_plan_ids : benefit_group.elected_dental_plan_ids)
        elected_plan_ids.include?(plan.renewal_plan(renewing_plan_year.start_on).id)
      else
       false
     end
   end

    def find_renewal_enrollments
      renewal_enrollments = family.active_household.hbx_enrollments.shop_market.by_coverage_kind(coverage_kind)
      renewal_enrollments.where({
        :benefit_group_id.in => renewing_plan_year.benefit_groups.pluck(:_id),
        :effective_on => renewing_plan_year.start_on,
        :aasm_state.nin => ['shopping', 'coverage_canceled']
        })
    end

    def renewal_assignment
      if renewing_plan_year.active?
        census_employee.active_benefit_group_assignment
      else
        census_employee.renewal_benefit_group_assignment
      end
    end

    def employer_offering_coverage_kind?
      coverage_kind == 'dental' ? renewal_assignment.benefit_group.is_offering_dental? : true
    end

    def assign_common_attributes(active_enrollment, renewal_enrollment)
      common_attributes = %w(coverage_household_id coverage_kind changing broker_agency_profile_id
          writing_agent_id original_application_type kind special_enrollment_period_id
        )
      common_attributes.each do |attr|
         renewal_enrollment.send("#{attr}=", active_enrollment.send(attr))
      end

      renewal_enrollment.plan_id = active_enrollment.plan.renewal_plan(renewing_plan_year.start_on).id if active_enrollment.plan.present?
      renewal_enrollment
    end

    def renew_enrollment(enrollment: nil, waiver: false)
      ShopEnrollmentRenewalFactory.new({
        family: family,
        census_employee: census_employee,
        employer: employer,
        renewing_plan_year: renewing_plan_year,
        enrollment: enrollment,
        is_waiver: waiver,
        coverage_kind: coverage_kind
      }).renew_coverage
    end

    # relationship offered in renewal plan year and member active in enrollment.
    def is_relationship_offered_and_member_covered?(member,renewal_enrollment)
      return true if renewal_enrollment.composite_rated?
      relationship = PlanCostDecorator.benefit_relationship(member.primary_relationship)
      relationship = "child_over_26" if relationship == "child_under_26" && member.person.age_on(@plan_year_start_on) >= 26
      (renewal_relationship_benefits(renewal_enrollment).include?(relationship) && member.is_covered_on?(@plan_year_start_on - 1.day))
    end

    def trigger_notice_dental(enrollment_id: nil)
      if !disable_notifications
        notice_name = yield
        begin
          hbx_enrollment = HbxEnrollment.by_hbx_id(enrollment_id).first
          census_employee.update_attributes!(employee_role_id: hbx_enrollment.employee_role.id.to_s ) if !census_employee.employee_role.present? && hbx_enrollment.present?
          ShopNoticesNotifierJob.perform_later(census_employee.id.to_s, yield, :hbx_enrollment => enrollment_id) unless Rails.env.test?
        rescue Exception => e
          Rails.logger.error { "Unable to deliver census employee notice for #{notice_name} to census_employee #{census_employee.id} due to #{e}" }
        end
      end
    end

    # Validate enrollment membership against benefit package-covered relationships
    def family_eligibility(active_enrollment, renewal_enrollment)

      coverage_household.coverage_household_members.each do |coverage_member|
        enrollment_member = HbxEnrollmentMember.new_from(coverage_household_member: coverage_member)
        enrollment_member.eligibility_date = enrollment.effective_on
        enrollment_member.coverage_start_on = enrollment.effective_on
        renewal_enrollment.hbx_enrollment_members << enrollment_member
      end
    end
  end

class FamilyEnrollmentRenewalFactoryError < StandardError; end
end
