#deprecated - not using anymore. added individual observers.

module BenefitSponsors
  module Observers
    class NoticeObserver

      attr_accessor :notifier

      def initialize
        @notifier = BenefitSponsors::Services::NoticeService.new
      end

      def benefit_application_update(new_model_event)
        current_date = TimeKeeper.date_of_record
        raise ArgumentError.new("expected ModelEvents::ModelEvent") unless new_model_event.is_a?(ModelEvents::ModelEvent)

        if BenefitSponsors::ModelEvents::BenefitApplication::REGISTERED_EVENTS.include?(new_model_event.event_key)
          benefit_application = new_model_event.klass_instance

          if new_model_event.event_key == :renewal_application_denied
            policy = enrollment_policy.business_policies_for(benefit_application, :end_open_enrollment)
            unless policy.is_satisfied?(benefit_application)

              if (policy.fail_results.include?(:minimum_participation_rule) || policy.fail_results.include?(:non_business_owner_enrollment_count))
                deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "renewal_employer_ineligibility_notice")

                benefit_application.benefit_sponsorship.census_employees.non_terminated.each do |ce|
                  if ce.employee_role.present?
                    deliver(recipient: ce.employee_role, event_object: benefit_application, notice_event: "employee_renewal_employer_ineligibility_notice")
                  end
                end
              end
            end
          end

          if new_model_event.event_key == :initial_application_submitted
            deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "initial_application_submitted")
          end

          if new_model_event.event_key == :zero_employees_on_roster
            trigger_zero_employees_on_roster_notice(benefit_application)
          end

          if new_model_event.event_key == :renewal_employer_open_enrollment_completed
            deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "renewal_employer_open_enrollment_completed")
          end

          if new_model_event.event_key == :renewal_application_submitted
            trigger_zero_employees_on_roster_notice(benefit_application)
            deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "renewal_application_published")
          end

          if new_model_event.event_key == :initial_employer_open_enrollment_completed
            deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "initial_employer_open_enrollment_completed")
          end

          if new_model_event.event_key == :renewal_application_created
            deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "renewal_application_created")
          end

          if new_model_event.event_key == :renewal_application_autosubmitted
            deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "plan_year_auto_published")
            trigger_zero_employees_on_roster_notice(benefit_application)
          end

          if new_model_event.event_key == :group_advance_termination_confirmation
            deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "group_advance_termination_confirmation")

            benefit_application.active_benefit_sponsorship.census_employees.active.each do |ce|
              deliver(recipient: ce.employee_role, event_object: benefit_application, notice_event: "notify_employee_of_group_advance_termination")
            end
          end
          
          if new_model_event.event_key == :ineligible_application_submitted
            policy = eligibility_policy.business_policies_for(benefit_application, :submit_benefit_application)
            unless policy.is_satisfied?(benefit_application)
              if benefit_application.is_renewing?
                if policy.fail_results.include?(:employer_primary_office_location)
                  deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "employer_renewal_eligibility_denial_notice")
                  benefit_application.active_benefit_sponsorship.census_employees.non_terminated.each do |ce|
                    if ce.employee_role.present?
                      deliver(recipient: ce.employee_role, event_object: benefit_application, notice_event: "termination_of_employers_health_coverage")
                    end
                  end
                end
              elsif (policy.fail_results.include?(:employer_primary_office_location) || policy.fail_results.include?(:benefit_application_fte_count))
                deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "employer_initial_eligibility_denial_notice")
              end
            end
          end

          if new_model_event.event_key == :renewal_enrollment_confirmation
            deliver(recipient: benefit_application.employer_profile,  event_object: benefit_application, notice_event: "renewal_employer_open_enrollment_completed" )
            benefit_application.active_benefit_sponsorship.census_employees.non_terminated.each do |ce|
              enrollments = ce.renewal_benefit_group_assignment.hbx_enrollments
              enrollment = enrollments.select{ |enr| (HbxEnrollment::ENROLLED_STATUSES + HbxEnrollment::RENEWAL_STATUSES).include?(enr.aasm_state) }.sort_by(&:updated_at).last
              if enrollment.present?
                deliver(recipient: ce.employee_role, event_object: enrollment, notice_event: "renewal_employee_enrollment_confirmation")
              end
            end
          end

          if new_model_event.event_key == :application_denied
            policy = enrollment_policy.business_policies_for(benefit_application, :end_open_enrollment)
            unless policy.is_satisfied?(benefit_application)
            
              if (policy.fail_results.include?(:minimum_participation_rule) || policy.fail_results.include?(:non_business_owner_enrollment_count))
                benefit_application.active_benefit_sponsorship.census_employees.non_terminated.each do |ce|
                  if ce.employee_role.present?
                    deliver(recipient: ce.employee_role, event_object: benefit_application, notice_event: "group_ineligibility_notice_to_employee")
                  end
                end
              end

              deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "initial_employer_application_denied")
            end
          end

          if BenefitSponsors::BenefitApplications::BenefitApplication::DATA_CHANGE_EVENTS.include?(new_model_event.event_key)
          end
        end
      end

      def eligibility_policy
        return @eligibility_policy if defined? @eligibility_policy
        @eligibility_policy = BenefitSponsors::BenefitApplications::AcaShopApplicationEligibilityPolicy.new
      end

      def enrollment_policy
        return @enrollment_policy if defined? @enrollment_policy
        @enrollment_policy = BenefitSponsors::BenefitApplications::AcaShopEnrollmentEligibilityPolicy.new
      end

      def organization_create(new_model_event)
        raise ArgumentError.new("expected ModelEvents::ModelEvent") unless new_model_event.is_a?(ModelEvents::ModelEvent)
        organization = new_model_event.klass_instance

        if BenefitSponsors::ModelEvents::Organization::REGISTERED_EVENTS.include?(new_model_event.event_key)
          if new_model_event.event_key == :welcome_notice_to_employer
            deliver(recipient: organization.employer_profile, event_object: organization.employer_profile, notice_event: "welcome_notice_to_employer")
          end
        end
      end

      #check this later
      def profile_update(new_model_event)
        raise ArgumentError.new("expected ModelEvents::ModelEvent") unless new_model_event.is_a?(ModelEvents::ModelEvent)
        employer_profile = new_model_event.klass_instance

        if BenefitSponsors::ModelEvents::Profile::REGISTERED_EVENTS.include?(new_model_event.event_key)
        end

        if BenefitSponsors::ModelEvents::Profile::OTHER_EVENTS.include?(new_model_event.event_key)
          if new_model_event.event_key == :welcome_notice_to_employer
            deliver(recipient: employer_profile, event_object: employer_profile, notice_event: "welcome_notice_to_employer")
          end
        end
      end

      def benefit_sponsorship_update(new_model_event)
        raise ArgumentError.new("expected ModelEvents::ModelEvent") unless new_model_event.is_a?(ModelEvents::ModelEvent)
        benefit_sponsorship = new_model_event.klass_instance
        employer_profile = benefit_sponsorship.profile
        if BenefitSponsors::ModelEvents::BenefitSponsorship::REGISTERED_EVENTS.include?(new_model_event.event_key)
          if new_model_event.event_key == :initial_employee_plan_selection_confirmation
            if employer_profile.is_new_employer?
              census_employees = benefit_sponsorship.census_employees.non_terminated
              census_employees.each do |ce|
                if ce.active_benefit_group_assignment.hbx_enrollment.present? && ce.active_benefit_group_assignment.hbx_enrollment.effective_on == employer_profile.active_benefit_sponsorship.benefit_applications.where(:aasm_state.in => [:enrollment_eligible, :enrollment_open]).first.start_on
                  deliver(recipient: ce.employee_role, event_object: ce.active_benefit_group_assignment.hbx_enrollment, notice_event: "initial_employee_plan_selection_confirmation")
                end
              end
            end
          end
        end
      end

      def hbx_enrollment_update(new_model_event)
        raise ArgumentError.new("expected ModelEvents::ModelEvent") unless new_model_event.is_a?(ModelEvents::ModelEvent)

        if HbxEnrollment::REGISTERED_EVENTS.include?(new_model_event.event_key)
          hbx_enrollment = new_model_event.klass_instance

          if hbx_enrollment.is_shop? && hbx_enrollment.census_employee.is_active?
            
            is_valid_employer_py_oe = (hbx_enrollment.sponsored_benefit_package.benefit_application.open_enrollment_period.cover?(hbx_enrollment.submitted_at) || hbx_enrollment.sponsored_benefit_package.benefit_application.open_enrollment_period.cover?(hbx_enrollment.created_at))

            if new_model_event.event_key == :notify_employee_of_plan_selection_in_open_enrollment
              if is_valid_employer_py_oe
                deliver(recipient: hbx_enrollment.employee_role, event_object: hbx_enrollment, notice_event: "notify_employee_of_plan_selection_in_open_enrollment") #renewal EE notice
              end
            end

            if new_model_event.event_key == :application_coverage_selected
              if is_valid_employer_py_oe
                deliver(recipient: hbx_enrollment.employee_role, event_object: hbx_enrollment, notice_event: "notify_employee_of_plan_selection_in_open_enrollment") #initial EE notice
              end
              
              if !is_valid_employer_py_oe && (hbx_enrollment.enrollment_kind == "special_enrollment" || hbx_enrollment.census_employee.new_hire_enrollment_period.cover?(TimeKeeper.date_of_record))
                deliver(recipient: hbx_enrollment.census_employee.employee_role, event_object: hbx_enrollment, notice_event: "employee_plan_selection_confirmation_sep_new_hire")
              end
            end
          end

          if new_model_event.event_key == :employee_waiver_confirmation
            deliver(recipient: hbx_enrollment.census_employee.employee_role, event_object: hbx_enrollment, notice_event: "employee_waiver_confirmation")
          end

          if new_model_event.event_key == :employee_coverage_termination
            if hbx_enrollment.is_shop? && (CensusEmployee::EMPLOYMENT_ACTIVE_STATES - CensusEmployee::PENDING_STATES).include?(hbx_enrollment.census_employee.aasm_state) && hbx_enrollment.sponsored_benefit_package.is_active
              deliver(recipient: hbx_enrollment.employer_profile, event_object: hbx_enrollment, notice_event: "employer_notice_for_employee_coverage_termination")
              deliver(recipient: hbx_enrollment.employee_role, event_object: hbx_enrollment, notice_event: "employee_notice_for_employee_coverage_termination")
            end
          end
        end
      end

      def document_update(new_model_event)
        raise ArgumentError.new("expected ModelEvents::ModelEvent") unless new_model_event.is_a?(ModelEvents::ModelEvent)

        if BenefitSponsors::ModelEvents::Document::REGISTERED_EVENTS.include?(new_model_event.event_key)
          document = new_model_event.klass_instance
          if new_model_event.event_key == :initial_employer_invoice_available
            employer_profile = document.documentable
            benefit_applications = employer_profile.latest_benefit_sponsorship.benefit_applications
            eligible_states = BenefitSponsors::BenefitApplications::BenefitApplication::ENROLLMENT_ELIGIBLE_STATES + BenefitSponsors::BenefitApplications::BenefitApplication::ENROLLING_STATES
            deliver(recipient: employer_profile, event_object: benefit_applications.where(:aasm_state.in => eligible_states).first, notice_event: "initial_employer_invoice_available")
          end
        end
      end

      def vlp_document_update; end
      def paper_application_update; end
      def employer_attestation_document_update; end

      def benefit_application_date_change(model_event)
        current_date = TimeKeeper.date_of_record
        if BenefitSponsors::ModelEvents::BenefitApplication::DATA_CHANGE_EVENTS.include?(model_event.event_key)

          if model_event.event_key == :low_enrollment_notice_for_employer
            BenefitSponsors::Queries::NoticeQueries.organizations_for_low_enrollment_notice(current_date).each do |benefit_sponsorship|
             begin
               benefit_application = benefit_sponsorship.benefit_applications.where(:aasm_state => :enrollment_open).first
               #exclude congressional employees
                next if ((benefit_application.benefit_packages.any?{|bg| bg.is_congress?}) || (benefit_application.effective_period.min.yday == 1))
                if benefit_application.enrollment_ratio < benefit_application.benefit_market.configuration.ee_ratio_min
                  deliver(recipient: benefit_sponsorship.employer_profile, event_object: benefit_application, notice_event: "low_enrollment_notice_for_employer")
                end
              end
            end
          end

          if [ :renewal_employer_publish_plan_year_reminder_after_soft_dead_line,
               :renewal_plan_year_first_reminder_before_soft_dead_line,
               :renewal_plan_year_publish_dead_line
          ].include?(model_event.event_key)
            current_date = TimeKeeper.date_of_record
            BenefitSponsors::Queries::NoticeQueries.organizations_for_force_publish(current_date).each do |benefit_sponsorship|
              benefit_application = benefit_sponsorship.benefit_applications.where(:aasm_state => :draft).first.is_renewing?
              deliver(recipient: benefit_sponsorship.employer_profile, event_object: benefit_application, notice_event: model_event.event_key.to_s)
            end
          end

          if [ :initial_employer_first_reminder_to_publish_plan_year,
               :initial_employer_second_reminder_to_publish_plan_year,
               :initial_employer_final_reminder_to_publish_plan_year
          ].include?(model_event.event_key)
            start_on = TimeKeeper.date_of_record.next_month.beginning_of_month
            organizations = BenefitSponsors::Queries::NoticeQueries.initial_employers_by_effective_on_and_state(start_on: start_on, aasm_state: :draft)
            organizations.each do|organization|
              benefit_application = organization.active_benefit_sponsorship.benefit_applications.where(:aasm_state => :draft).first
              deliver(recipient: organization.employer_profile, event_object: benefit_application, notice_event: model_event.event_key.to_s)
            end
          end

          if model_event.event_key == :initial_employer_no_binder_payment_received
            BenefitSponsors::Queries::NoticeQueries.initial_employers_in_enrolled_state.each do |benefit_sponsorship|
              if !benefit_sponsorship.initial_enrollment_eligible?
                eligible_states = BenefitSponsors::BenefitApplications::BenefitApplication::ENROLLMENT_ELIGIBLE_STATES + BenefitSponsors::BenefitApplications::BenefitApplication::ENROLLING_STATES
                benefit_application = benefit_sponsorship.benefit_applications.where(:aasm_state.in => eligible_states).first
                deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "initial_employer_no_binder_payment_received")
                #Notice to employee that there employer misses binder payment
                org.active_benefit_sponsorship.census_employees.active.each do |ce|
                  begin
                    deliver(recipient: ce.employee_role, event_object: benefit_application, notice_event: "notice_to_ee_that_er_plan_year_will_not_be_written")
                  end
                end
              end
            end
          end
        end
      end

      def special_enrollment_period_update(new_model_event)
        special_enrollment_period = new_model_event.klass_instance

        if special_enrollment_period.is_shop?
          primary_applicant = special_enrollment_period.family.primary_applicant
          if employee_role = primary_applicant.person.active_employee_roles[0]
            deliver(recipient: employee_role, event_object: special_enrollment_period, notice_event: "employee_sep_request_accepted") 
          end
        end
      end

      def broker_agency_account_update(new_model_event)
        broker_agency_account = new_model_event.klass_instance
        broker_agency_profile = broker_agency_account.broker_agency_profile
        broker = broker_agency_profile.primary_broker_role
        employer_profile = broker_agency_account.employer_profile

        if BrokerAgencyAccount::BROKER_HIRED_EVENTS.include?(new_model_event.event_key)
          deliver(recipient: broker, event_object: employer_profile, notice_event: "broker_hired_notice_to_broker")
          deliver(recipient: broker_agency_profile, event_object: employer_profile, notice_event: "broker_agency_hired_confirmation")
          deliver(recipient: employer_profile, event_object: employer_profile, notice_event: "broker_hired_confirmation_to_employer")
        end

        if BrokerAgencyAccount::BROKER_FIRED_EVENTS.include?(new_model_event.event_key)
          deliver(recipient: broker, event_object: employer_profile, notice_event: "broker_fired_confirmation_to_broker")
          deliver(recipient: broker_agency_profile, event_object: employer_profile, notice_event: "broker_agency_fired_confirmation")
          deliver(recipient: employer_profile, event_object: broker_agency_account, notice_event: "broker_fired_confirmation_to_employer")
        end
      end

      def employer_profile_date_change; end
      def hbx_enrollment_date_change; end
      def census_employee_date_change; end
      def document_date_change; end
      def special_enrollment_period_date_change; end
      def broker_agency_account_date_change; end

      def census_employee_update(new_model_event)
        raise ArgumentError.new("expected ModelEvents::ModelEvent") unless new_model_event.is_a?(ModelEvents::ModelEvent)
        census_employee = new_model_event.klass_instance

        if CensusEmployee::OTHER_EVENTS.include?(new_model_event.event_key)
          deliver(recipient: census_employee.employee_role, event_object: new_model_event.options[:event_object], notice_event: new_model_event.event_key.to_s)
        end
        
        if CensusEmployee::REGISTERED_EVENTS.include?(new_model_event.event_key)
         if new_model_event.event_key == :employee_notice_for_employee_terminated_from_roster
          deliver(recipient: census_employee.employee_role, event_object: census_employee, notice_event: "employee_notice_for_employee_terminated_from_roster")
         end
        end
      end

      def deliver(recipient:, event_object:, notice_event:, notice_params: {})
        notifier.deliver(recipient: recipient, event_object: event_object, notice_event: notice_event, notice_params: notice_params)
      end

      def trigger_zero_employees_on_roster_notice(benefit_application)
        # TODO: Update the query to exclude congressional employees
        # if !benefit_application.benefit_packages.any?{|bg| bg.is_congress?} && benefit_application.benefit_sponsorship.census_employees.active.count < 1
        if benefit_application.benefit_sponsorship.census_employees.active.count < 1
          deliver(recipient: benefit_application.employer_profile, event_object: benefit_application, notice_event: "zero_employees_on_roster_notice")
        end
      end

    end
  end
end