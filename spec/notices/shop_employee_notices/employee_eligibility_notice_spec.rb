require 'rails_helper'

RSpec.describe ShopEmployeeNotices::EmployeeEligibilityNotice, :dbclean => :after_each do
  let(:start_on) { TimeKeeper.date_of_record.beginning_of_month + 1.month - 1.year}
  let!(:person){ create :person }
  let(:employee_role) {FactoryGirl.create(:employee_role, person: person, employer_profile: employer_profile)}
  let(:census_employee) { FactoryGirl.create(:census_employee, employee_role_id: employee_role.id, benefit_sponsors_employer_profile_id: employer_profile.id, benefit_sponsorship_id: employer_profile.benefit_sponsorships.first.id) }
  let(:application_event){ double("ApplicationEventKind",{
                            :name =>'Employee Eligibility Notice',
                            :notice_template => 'notices/shop_employee_notices/employee_eligibility_notice',
                            :notice_builder => 'ShopEmployeeNotices::EmployeeEligibilityNotice',
                            :event_name => 'employee_eligibility_notice',
                            :mpi_indicator => 'DAE053',
                            :title => "Employee Eligibility Notice"})
                          }

    let(:valid_parmas) {{
        :subject => application_event.title,
        :mpi_indicator => application_event.mpi_indicator,
        :event_name => application_event.event_name,
        :template => application_event.notice_template
    }}

    let(:site) { FactoryGirl.create(:benefit_sponsors_site,  :with_benefit_market, :dc, :as_hbx_profile) }

    let(:organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization,
      :with_aca_shop_dc_employer_profile_initial_application,
      site: site
     )}

    let(:employer_profile) { organization.employer_profile }

  describe "New" do
    before do
      @employee_notice = ShopEmployeeNotices::EmployeeEligibilityNotice.new(census_employee, valid_parmas)
    end
    context "valid params" do
      it "should initialze" do
        expect{ShopEmployeeNotices::EmployeeEligibilityNotice.new(census_employee, valid_parmas)}.not_to raise_error
      end
    end

    context "invalid params" do
      [:mpi_indicator,:subject,:template].each do  |key|
        it "should NOT initialze with out #{key}" do
          valid_parmas.delete(key)
          expect{ShopEmployeeNotices::EmployeeEligibilityNotice.new(census_employee, valid_parmas)}.to raise_error(RuntimeError,"Required params #{key} not present")
        end
      end
    end
  end

  describe "Build" do
    before do
      @employee_notice = ShopEmployeeNotices::EmployeeEligibilityNotice.new(census_employee, valid_parmas)
    end
    it "should build notice with all necessary information" do
      @employee_notice.build
      expect(@employee_notice.notice.primary_fullname).to eq person.full_name.titleize
      expect(@employee_notice.notice.employer_name).to eq employer_profile.organization.legal_name.titleize
    end
    it "should render notice template" do
      expect(@employee_notice.template).to eq "notices/shop_employee_notices/employee_eligibility_notice"
    end
  end

  describe "#generate_pdf_notice" do
    before do
      @employee_notice = ShopEmployeeNotices::EmployeeEligibilityNotice.new(census_employee, valid_parmas)
    end

    it "should create a pdf" do
      @employee_notice.build
      file = @employee_notice.generate_pdf_notice
      expect(File.exist?(file.path)).to be true
    end
  end

end
