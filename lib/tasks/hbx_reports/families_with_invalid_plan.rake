require 'csv'
 # This is a report that generated for business validation.
 # The task to run is RAILS_ENV=production bundle exec rake reports:families_with_invalid_shop_plan
namespace :reports do
 
  desc "List of families having invalid shop plan"
  task :families_with_invalid_shop_plan => :environment do

    field_names  = %w(
      ENROLLMENT_HBX_ID
      ENROLLMENT_START_ON
      ENROLLMENT_STATUS
      ENROLLMENT_HIOS_ID
      ENROLLMENT_APPLICANT_FIRST_NAME
      ENROLLMENT_APPLICANT_LAST_NAME
      ENROLLMENT_APPLICANT_HBX_ID
      ENROLLMENT_APPLICANT_STATE
      ENROLLMENT_EMPLOYER_NAME
      ENROLLMENT_EMPLOYER_PLAN_YEAR_START_ON
      ER FEIN
    )
    invalid_plan_ids = [BSON::ObjectId('59f72ce1faca145fb8001c52'), BSON::ObjectId('59f72ce1faca145fb8001ccf'), BSON::ObjectId('59f72ce1faca145fb8001a5e')]

    file_name = "#{Rails.root}/public/families_with_invalid_shop_plan.csv"

    def employment_status(person, employee_role_id)
      return nil if employee_role_id.nil?
      person.active_employee_roles.map(&:id).include? employee_role_id
    end

    CSV.open(file_name, "w", force_quotes: true) do |csv|
      csv << field_names

      families = Family.where(:"households.hbx_enrollments" =>
        {:"$elemMatch" =>
          {
            :plan_id => {:"$in" => invalid_plan_ids},
            :aasm_state => {:"$in" => HbxEnrollment::ENROLLED_STATUSES},
            :kind => {:"$in" => ["employer_sponsored", "employer_sponsored_cobra"]}
          }
        }
      )

      families.each do |family|
        person = family.primary_applicant.person
        family.active_household.hbx_enrollments.shop_market.enrolled.where(:"plan_id".in => invalid_plan_ids).each do |enrollment|

          plan_year = enrollment.benefit_group.plan_year

            csv << [
              enrollment.hbx_id,
              enrollment.effective_on,
              enrollment.aasm_state,
              enrollment.plan.hios_id,
              person.first_name,
              person.last_name,
              person.hbx_id,
              employment_status(person, enrollment.employee_role_id),
              plan_year.employer_profile.parent.legal_name,
              plan_year.start_on,
              plan_year.employer_profile.parent.fein
            ]
        end
      end
      puts "*********** Finished generating Report ***********************"
    end

    puts "*********** Canceling the Incorrect Enrollments **************"

    families.each do |family|
      family.active_household.hbx_enrollments.shop_market.enrolled.where(:"plan_id".in => invalid_plan_ids).each do |enrollment|
        enrollment.cancel_coverage! if enrollment.may_cancel_coverage?
        puts "Enrollment with hbx_id #{enrollment.hbx_id} canceled"
      end
    end

    puts "*********** Cancellation Finished **************"

    invalid_plan_ids.each do |plan_id|
      plan = Plan.find(plan_id)
      plan.update_attributes!(nationwide: false, dc_in_network: true)
      puts "Changing Network Field Value from Nationwide to DC Metro for #{plan.hios_id}"
    end
  end
end
