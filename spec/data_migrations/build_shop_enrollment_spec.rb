require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "build_shop_enrollment")

describe BuildShopEnrollment do

  let(:given_task_name) { "build_shop_enrollment" }
  subject { BuildShopEnrollment.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "creating a new shop enrollment", dbclean: :after_each do
    let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: person)}
    let(:person) { FactoryGirl.create(:person, :with_employee_role)}
    let!(:benefit_group) { FactoryGirl.create(:benefit_group, plan_year: plan_year)}
    let(:plan_year) { FactoryGirl.create(:plan_year, employer_profile: person.employee_roles[0].employer_profile, aasm_state: "active")}
    let(:census_employee) { FactoryGirl.create(:census_employee, employer_profile: plan_year.employer_profile)}
    before do
      allow(ENV).to receive(:[]).with("person_hbx_id").and_return(person.hbx_id)
      allow(ENV).to receive(:[]).with("effective_on").and_return(TimeKeeper.date_of_record)
      allow(ENV).to receive(:[]).with("plan_year_state").and_return(plan_year.aasm_state)
      allow(ENV).to receive(:[]).with("new_hbx_id").and_return("1234567")
      person.employee_roles[0].update_attributes(census_employee_id: census_employee.id)
      census_employee.update_attributes(employee_role_id: person.employee_roles[0].id)
      subject.migrate
      person.reload
    end

    it "should create a new enrollment" do
      enrollments = person.primary_family.active_household.hbx_enrollments
      expect(enrollments.size).to eq 1
    end

    it "should have the given effective_on date" do
      expect(person.primary_family.active_household.hbx_enrollments.first.effective_on).to eq TimeKeeper.date_of_record
    end

    it "should have the updated hbx_id" do
      expect(person.primary_family.active_household.hbx_enrollments.first.hbx_id).to eq "1234567"
    end

    it "should be in enrolled statuses" do
      expect(HbxEnrollment::ENROLLED_STATUSES.include?(person.primary_family.active_household.hbx_enrollments.first.aasm_state)).to eq true
    end
  end
end
