require 'rails_helper'

describe "shared/_my_portal_links.html.haml", dbclean: :after_each do

  context "with employee role" do
    let(:user) { FactoryGirl.create(:user, person: person, roles: ["employee"]) }
    let(:person) { FactoryGirl.create(:person, :with_employee_role)}

    it "should have one portal link" do
      all_census_ee = FactoryGirl.create(:census_employee)
      all_er_profile = all_census_ee.employer_profile
      person.employee_roles.first.census_employee = all_census_ee
      person.employee_roles.first.save!
      sign_in(user)
      render 'shared/my_portal_links'
      expect(rendered).to have_content('My Insured Portal')
      expect(rendered).to_not have_selector('dropdownMenu1')
    end

  end

  context "with employer role & employee role" do
    let(:general_organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_site, :with_aca_shop_cca_employer_profile) }
    let(:employer_profile)    { general_organization.employer_profile }
    let(:benefit_sponsorship) { employer_profile.add_benefit_sponsorship }
    let(:active_employer_staff_role) {FactoryGirl.create(:benefit_sponsor_employer_staff_role, aasm_state:'is_active', benefit_sponsor_employer_profile_id: employer_profile.id)}
    let(:user) { FactoryGirl.create(:user, person: person, roles: ["employee", "employer_staff"]) }
    let(:person) { FactoryGirl.create(:person, :with_employee_role, :with_employer_staff_role)}
    let!(:employee_role) { FactoryGirl.create(:employee_role, person: person)}
    let(:census_employee) {FactoryGirl.create(:benefit_sponsors_census_employee, employer_profile: employer_profile, employee_role_id: employee_role.id)}

    it "should have one portal links and popover" do
      allow(employer_profile).to receive(:active_benefit_sponsorship).and_return(benefit_sponsorship)
      employer_profile.reload
      employee_role.new_census_employee = census_employee
      allow(user).to receive(:has_employee_role?).and_return(true)
      sign_in(user)
      render 'shared/my_portal_links'
      expect(rendered).to have_content('My Insured Portal')
      expect(rendered).to have_content(census_employee.employer_profile.legal_name)
      expect(rendered).to have_selector('.dropdown-menu')
      expect(rendered).to have_selector('.dropdown-menu')
      expect(rendered).to match(/Insured/)
    end
  end

  context "with employer roles & employee role" do
    let(:user) { FactoryGirl.create(:user, person: person, roles: ["employee", "employer_staff"]) }
    let(:site)            { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let(:benefit_sponsor)     { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    let(:employer_profile)    { benefit_sponsor.employer_profile }
    let(:active_employer_staff_role) {FactoryGirl.create(:benefit_sponsor_employer_staff_role, aasm_state:'is_active', benefit_sponsor_employer_profile_id: employer_profile.id)}
    let(:person) { FactoryGirl.create(:person, :with_employee_role, employer_staff_roles:[active_employer_staff_role]) }
    let!(:employee_role) { FactoryGirl.create(:employee_role, person: person)}
    let(:benefit_sponsorship)    { BenefitSponsors::BenefitSponsorships::BenefitSponsorship.new(profile: employer_profile) }

    it "should have one portal links and popover" do
      allow(employer_profile).to receive(:active_benefit_sponsorship).and_return(benefit_sponsorship)
      employer_profile.reload
      all_census_ee = FactoryGirl.create(:benefit_sponsors_census_employee, employer_profile: employer_profile, employee_role_id: employee_role.id)
      all_er_profile = all_census_ee.employer_profile
      all_er_profile.organization.update_attributes(legal_name: 'Second Company') # not always Turner
      EmployerStaffRole.create(person:person, benefit_sponsor_employer_profile_id: all_er_profile.id)
      person.employee_roles.first.census_employee = all_census_ee
      person.employee_roles.first.save!
      sign_in(user)
      render 'shared/my_portal_links'
      expect(rendered).to have_content('My Insured Portal')
      expect(rendered).to have_content(all_er_profile.legal_name)
      expect(rendered).to have_content('Second Company')
      expect(rendered).to have_selector('.dropdown-menu')
      expect(rendered).to have_selector('.dropdown-menu')
      expect(rendered).to match(/Insured/)
    end
  end

end
