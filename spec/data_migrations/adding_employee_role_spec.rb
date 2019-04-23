require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "adding_employee_role")

describe AddingEmployeeRole, dbclean: :after_each do
  let!(:site) { create(:benefit_sponsors_site,:with_benefit_market, :with_benefit_market_catalog_and_product_packages, :as_hbx_profile, :cca) }
  let!(:org) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  let(:employer_profile) { org.employer_profile }
  let!(:rating_area) { FactoryGirl.create_default :benefit_markets_locations_rating_area }
  let!(:service_area) { FactoryGirl.create_default :benefit_markets_locations_service_area }
  let(:benefit_sponsorship) { employer_profile.add_benefit_sponsorship }
  let(:family) { FactoryGirl.create(:family, :with_primary_family_member) }
  let(:benefit_market) { site.benefit_markets.first }
  let(:benefit_market_catalog) { benefit_market.benefit_market_catalogs.first }
  let!(:product_package) { benefit_market_catalog.product_packages.where(package_kind: :single_issuer).first }
  let!(:benefit_package) { FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: benefit_application, product_package: product_package) }
  let!(:benefit_application) { FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, aasm_state: :active) }
  let(:hbx_enrollment) { FactoryGirl.create(:hbx_enrollment, sponsored_benefit_package_id: benefit_package.id, household: family.active_household)}
  let(:benefit_group_assignment) {FactoryGirl.build(:benefit_group_assignment, benefit_package: benefit_package, hbx_enrollment: hbx_enrollment, start_on: benefit_application.start_on) }
  let(:benefit_group_assignment2) {FactoryGirl.build(:benefit_group_assignment, benefit_package: benefit_package, hbx_enrollment: hbx_enrollment, start_on: benefit_application.start_on) }
  let(:benefit_group_assignment3) {FactoryGirl.build(:benefit_group_assignment, benefit_package: benefit_package, hbx_enrollment: hbx_enrollment, start_on: benefit_application.start_on) }
  let(:census_employee) { FactoryGirl.create(:benefit_sponsors_census_employee, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship) }
  let(:census_employee2) { FactoryGirl.create(:benefit_sponsors_census_employee, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship) }
  let(:census_employee3) { FactoryGirl.create(:benefit_sponsors_census_employee, employer_profile: employer_profile, benefit_sponsorship: benefit_sponsorship) }

  let(:given_task_name) { "adding_employee_role" }
  subject { AddingEmployeeRole.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "creating new employee role", dbclean: :after_each do
    let(:person) { FactoryGirl.create(:person, ssn: "009998887") }

    context 'When params are missing/invalid' do
      context 'when census_employee_id not provided then' do
        before(:each) do
          ENV['action'] = 'Add'
        end
        it 'should raise an error' do
          expect(subject.migrate).to eq('Please provide census_employee_id.')
        end
      end

      context 'when census employee id is invalid then' do
        before(:each) do
          allow(ENV).to receive(:[]).with('action').and_return('Add')
          allow(ENV).to receive(:[]).with('census_employee_id').and_return '123abc987pqr'
        end
        it 'should raise an error' do
          expect(subject.migrate).to eq('No Census Employee found by 123abc987pqr')
        end
      end

      context 'when person_id not provided then' do
        before(:each) do
          ENV['action'] = 'Add'
          ENV['census_employee_id'] = census_employee.id
        end
        it 'should raise an error' do
          expect(subject.migrate).to eq('Please provide person_id.')
        end
      end

      context 'when census person_id is invalid then' do
        before(:each) do
          allow(ENV).to receive(:[]).with('action').and_return('Add')
          allow(ENV).to receive(:[]).with('census_employee_id').and_return census_employee.id
          allow(ENV).to receive(:[]).with('person_id').and_return '123abc987pqr'
        end
        it 'should raise an error' do
          expect(subject.migrate).to eq('Person not found by 123abc987pqr')
        end
      end
    end

    context 'employee without an employee role' do
      before(:each) do
        census_employee.update_attribute(:employer_profile_id, employer_profile.id)
        allow(ENV).to receive(:[]).with('action').and_return('Add')
        allow(ENV).to receive(:[]).with('census_employee_id').and_return(census_employee.id)
        allow(ENV).to receive(:[]).with('person_id').and_return(person.id)
        census_employee.benefit_group_assignments << benefit_group_assignment
        census_employee.save!
        benefit_group_assignment.save!
      end
      it 'should link employee role' do
        expect(census_employee.employee_role).to eq nil
        subject.migrate
        census_employee.reload
        expect(census_employee.employee_role).not_to eq nil
      end
    end
  end

  describe "census employee's not linked" do

    context 'When ENV params are invalid' do
      context 'when action is invalid then' do
        before(:each) do
          allow(ENV).to receive(:[]).with('action').and_return('Hello')
        end
        it 'should raise an error' do
          expect(subject.migrate).to eq('Invalid action Hello!')
        end
      end

      context 'when ce ids not provided then' do
        before(:each) do
          ENV['action'] = 'Link'
        end
        it 'should raise an error' do
          expect(subject.migrate).to eq('Please provide census_employee_ids.')
        end
      end

      context 'when census employee id is invalid then' do
        before(:each) do
          allow(ENV).to receive(:[]).with('action').and_return('Link')
          allow(ENV).to receive(:[]).with('census_employee_ids').and_return '123abc987pqr'
        end
        it 'should raise an error' do
          expect(subject.migrate).to eq('No Census Employee found with 123abc987pqr')
        end
      end
    end

    context 'when benefit application state is not published then' do
      let!(:benefit_application) { FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, aasm_state: :draft) }
      before(:each) do
        allow(ENV).to receive(:[]).with('action').and_return('Link')
        allow(ENV).to receive(:[]).with('census_employee_ids').and_return "#{census_employee.id}"
        census_employee.benefit_group_assignments << benefit_group_assignment
        census_employee.save!
        benefit_group_assignment.save!
      end
      it 'employee state should not be changed to employee_role_linked' do
        expect(census_employee.aasm_state).to eq 'eligible'
        subject.migrate
        census_employee.reload
        expect(census_employee.aasm_state).to eq 'eligible'
      end
    end

    context 'when census employee ids are valid' do
      before(:each) do
        allow(ENV).to receive(:[]).with('action').and_return('Link')
        allow(ENV).to receive(:[]).with('census_employee_ids').and_return "#{census_employee.id}, #{census_employee2.id}, #{census_employee3.id}"
        census_employee.benefit_group_assignments << benefit_group_assignment
        census_employee.save!
        benefit_group_assignment.save!
        census_employee2.benefit_group_assignments << benefit_group_assignment2
        census_employee2.save!
        benefit_group_assignment2.save!
        census_employee3.benefit_group_assignments << benefit_group_assignment3
        census_employee3.save!
        benefit_group_assignment3.save!
      end
      it 'employees should have eligible state then employee role linked states' do
        expect(census_employee.aasm_state).to eq 'eligible'
        expect(census_employee2.aasm_state).to eq 'eligible'
        expect(census_employee3.aasm_state).to eq 'eligible'
        subject.migrate
        census_employee.reload
        census_employee2.reload
        census_employee3.reload
        expect(census_employee.aasm_state).to eq 'employee_role_linked'
        expect(census_employee2.aasm_state).to eq 'employee_role_linked'
        expect(census_employee3.aasm_state).to eq 'employee_role_linked'
      end
    end
  end
end