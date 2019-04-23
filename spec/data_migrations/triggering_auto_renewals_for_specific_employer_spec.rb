require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "triggering_auto_renewals_for_specific_employer")

describe TriggeringAutoRenewalsForSpecificEmployer, dbclean: :after_each do
  skip "ToDo rake was never updated to new model, check if we can remove it" do

    let(:given_task_name) { "triggering_auto_renewals_for_specific_employer" }
    subject { TriggeringAutoRenewalsForSpecificEmployer.new(given_task_name, double(:current_scope => nil)) }

    describe "given a task name" do
      it "has the given task name" do
        expect(subject.name).to eql given_task_name
      end
    end

    describe "generating auto-renewals for census employees", dbclean: :after_each do

      let(:organization) { FactoryGirl.create :organization, :with_active_and_renewal_plan_years}
      let(:census_employee) { FactoryGirl.create :census_employee, employer_profile: organization.employer_profile, dob: TimeKeeper.date_of_record - 30.years, first_name: person.first_name, last_name: person.last_name }
      let(:employee_role) { FactoryGirl.create(:employee_role, person: person, census_employee: census_employee, employer_profile: organization.employer_profile)}
      let(:person) { FactoryGirl.create(:person)}
      let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: person)}

      before do
        census_employee.update_attributes(:employee_role =>  employee_role, :employee_role_id =>  employee_role.id)
        census_employee.update_attribute(:ssn, census_employee.employee_role.person.ssn)
        new_date = TimeKeeper.date_of_record.beginning_of_month + 11.days
        TimeKeeper.set_date_of_record_unprotected!(new_date)
        start_on = Date.new(2016,1,1) # we can fix it better some-time later
        organization.employer_profile.plan_years.where(aasm_state: "active").first.update_attributes(start_on: start_on,
          :end_on => start_on + 1.year - 1.day, :open_enrollment_start_on => (start_on - 30).beginning_of_month,
          :open_enrollment_end_on => (start_on - 30).beginning_of_month + 1.weeks
          )
        start_on = start_on + 1.year
        organization.employer_profile.plan_years.where(aasm_state: "renewing_enrolling").first.update_attributes(start_on: start_on,
          :end_on => start_on + 1.year - 1.day, :open_enrollment_start_on => (start_on - 30).beginning_of_month,
          :open_enrollment_end_on => (start_on - 30).beginning_of_month + 1.weeks
          )
        allow(ENV).to receive(:[]).with("fein").and_return(organization.fein)
      end

      after :all do
        TimeKeeper.set_date_of_record_unprotected!(Date.today)
      end

      context "triggering a new enrollment", dbclean: :after_each do

        let!(:hbx_enrollment) { FactoryGirl.create(:hbx_enrollment, household: family.active_household, effective_on: Date.new(2016,1,1), plan: plan)}
        let(:renewal_plan) { FactoryGirl.create(:plan)}
        let(:plan) { FactoryGirl.create(:plan, :with_premium_tables, :renewal_plan_id => renewal_plan.id)}
        before :each do
          hbx_enrollment.update_attributes(:benefit_group_id => organization.employer_profile.plan_years.where(aasm_state: "active").first.benefit_groups.first.id, :benefit_group_assignment => census_employee.active_benefit_group_assignment)
          census_employee.renewal_benefit_group_assignment.benefit_group.elected_plan_ids << hbx_enrollment.plan.renewal_plan_id
          census_employee.renewal_benefit_group_assignment.benefit_group.save!
        end

        it "should trigger a auto-renewing enrollment if we have an an active enrollment", dbclean: :after_each do
          subject.migrate
          household = organization.employer_profile.census_employees.first.employee_role.person.primary_family.active_household
          household.reload
          expect(household.hbx_enrollments.by_coverage_kind('health').size).to eq 2
          expect(household.hbx_enrollments.by_coverage_kind('health').where(aasm_state: "auto_renewing").size).to eq 1
        end

        it "should trigger a renewing waived enrollment if the previous existing enrollment is inactive", dbclean: :after_each do
          hbx_enrollment.update_attribute(:aasm_state, "inactive")
          subject.migrate
          household = organization.employer_profile.census_employees.first.employee_role.person.primary_family.active_household
          household.reload
          expect(household.hbx_enrollments.by_coverage_kind('health').size).to eq 2
          expect(household.hbx_enrollments.by_coverage_kind('health').where(aasm_state: "renewing_waived").size).to eq 1
        end

        it "should not trigger an enrollment if we already have an enrollment with renewing plan year", dbclean: :after_each do
          hbx_enrollment.update_attributes(:benefit_group_id => organization.employer_profile.renewing_plan_year.benefit_groups.first.id, :benefit_group_assignment => census_employee.renewal_benefit_group_assignment)
          hbx_enrollment.update_attribute(:effective_on, organization.employer_profile.renewing_plan_year.start_on)
          subject.migrate
          household = organization.employer_profile.census_employees.first.employee_role.person.primary_family.active_household
          household.reload
          expect(household.hbx_enrollments.by_coverage_kind('health').size).to eq 1
        end
      end

      context "Triggers a new waived enrollment" do
        it "should not generate passive waiver when employee not covered under current plan year", dbclean: :after_each do
          subject.migrate
          household = organization.employer_profile.census_employees.first.employee_role.person.primary_family.active_household
          household.reload
          expect(household.hbx_enrollments.by_coverage_kind('health').empty?).to be_truthy
        end
      end
    end
  end
end
