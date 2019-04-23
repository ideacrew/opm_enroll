require 'rails_helper'
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

RSpec.describe Insured::PlanShoppingsController, :type => :controller, dbclean: :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"

  let(:person) {FactoryGirl.create(:person)}
  let(:user) { FactoryGirl.create(:user, person: person) }
  let(:family){ FactoryGirl.create(:family, :with_primary_family_member_and_dependent) }
  let(:family_members){ family.family_members.where(is_primary_applicant: false).to_a }
  let(:household){ family.active_household }
  let(:hbx_enrollment_member){ FactoryGirl.build(:hbx_enrollment_member, is_subscriber:true,  applicant_id: family.family_members.first.id, coverage_start_on: (TimeKeeper.date_of_record).beginning_of_month, eligibility_date: (TimeKeeper.date_of_record).beginning_of_month) }
  let(:product) { FactoryGirl.create(:benefit_markets_products_health_products_health_product) }
  let(:reference_plan) {double("Product")}
  let(:member_enrollment) {BenefitSponsors::Enrollments::MemberEnrollment.new(member_id:hbx_enrollment_member.id, product_price:BigDecimal(100),sponsor_contribution:BigDecimal(100))}
  let(:group_enrollment) {BenefitSponsors::Enrollments::GroupEnrollment.new(product: product, member_enrollments:[member_enrollment], product_cost_total:'')}
  let(:hbx_enrollment){ FactoryGirl.create(:hbx_enrollment, :with_product, sponsored_benefit_package_id: benefit_group_assignment.benefit_group.id,
                                           household: household,
                                           hbx_enrollment_members: [hbx_enrollment_member],
                                           coverage_kind: "health",
                                           external_enrollment: false,
                                           sponsored_benefit_id: sponsored_benefit.id,
                                           rating_area_id: rating_area.id)
  }
  let(:benefit_group) { current_benefit_package }
  let(:usermailer) {double("UserMailer")}
  let!(:census_employee) { FactoryGirl.create(:census_employee, :with_active_assignment, benefit_sponsorship: benefit_sponsorship, employer_profile: abc_profile, benefit_group: current_benefit_package ) }
  let(:benefit_group_assignment) { census_employee.active_benefit_group_assignment }
  let!(:employee_role) { FactoryGirl.create(:employee_role, person: person, employer_profile: abc_profile, census_employee_id: census_employee.id) }
  let!(:sponsored_benefit) { initial_application.benefit_packages.first.sponsored_benefits.first }
  let(:rate_schedule_date) {TimeKeeper.date_of_record}
  let(:cost_calculator) { HbxEnrollmentSponsoredCostCalculator.new(hbx_enrollment) }

  context "POST checkout" do
    before do
      allow(BenefitMarkets::Products::Product).to receive(:find).with("plan_id").and_return(product)
      allow(HbxEnrollment).to receive(:find).with("hbx_id").and_return(hbx_enrollment)
      allow(hbx_enrollment).to receive(:product=).with(product).and_return(true)
      allow(hbx_enrollment).to receive(:benefit_group).and_return(benefit_group)
      allow(hbx_enrollment).to receive(:can_select_coverage?).and_return true
      allow(hbx_enrollment).to receive(:is_special_enrollment?).and_return false
      allow(benefit_group).to receive(:reference_plan).and_return(:reference_plan)
      allow(PlanCostDecorator).to receive(:new).and_return(true)
      allow(hbx_enrollment).to receive(:save).and_return(true)
      allow(UserMailer).to receive(:plan_shopping_completed).and_return(usermailer)
      allow(usermailer).to receive(:deliver_now).and_return(true)
      allow(hbx_enrollment).to receive(:employee_role).and_return(employee_role)
      allow(employee_role).to receive(:hired_on).and_return(TimeKeeper.date_of_record + 10.days)
      allow(hbx_enrollment).to receive(:update_current).and_return(true)

      sign_in user
    end

    it "should get person" do
      post :checkout, id: "hbx_id", plan_id: "plan_id"
      expect(assigns(:person)).to eq person
    end

    it "returns http success" do
      post :checkout, id: "hbx_id", plan_id: "plan_id"
      expect(response).to have_http_status(:redirect)
    end

    it "should delete pre_hbx_enrollment_id session" do
      session[:pre_hbx_enrollment_id] = "123"
      post :checkout, id: "hbx_id", plan_id: "plan_id"
      expect(response).to have_http_status(:redirect)
      expect(session[:pre_hbx_enrollment_id]).to eq nil
    end

    context "employee hire_on date greater than enrollment date" do
      it "fails" do
        post :checkout, id: "hbx_id", plan_id: "plan_id"
        expect(flash[:error]).to include("You are attempting to purchase coverage prior to your date of hire on record. Please contact your Employer for assistance")
      end
    end

    context "hbx_enrollment can not select_coverage" do
      let(:errors) { double }
      before :each do
        request.env["HTTP_REFERER"] = "/home"
        allow(employee_role).to receive(:hired_on).and_return(TimeKeeper.date_of_record - 10.days)
        allow(hbx_enrollment).to receive(:can_select_coverage?).and_return false
        allow(hbx_enrollment).to receive(:errors).and_return(errors)
        allow(errors).to receive(:full_messages).and_return("You can not keep an existing plan which belongs to previous plan year")
      end

      it "should redirect" do
        post :checkout, id: "hbx_id", plan_id: "plan_id"
        expect(response).to have_http_status(:redirect)
      end

      it "should get flash" do
        post :checkout, id: "hbx_id", plan_id: "plan_id"
        expect(flash[:error]).to include("You can not keep an existing plan which belongs to previous plan year")
      end
    end
  end

  context "GET receipt" do
    let(:member_group) { double("MEMBERGROUP")}

    before do
      allow(HbxEnrollment).to receive(:find).with("id").and_return(hbx_enrollment)
      allow(hbx_enrollment).to receive(:sponsored_benefit).and_return(sponsored_benefit)
      allow(hbx_enrollment).to receive(:rating_area).and_return(rating_area)
      allow(hbx_enrollment).to receive(:is_shop?).and_return(false)
      allow(hbx_enrollment).to receive(:product).and_return(product)
      allow(hbx_enrollment).to receive(:benefit_group).and_return(benefit_group)
      allow(hbx_enrollment).to receive(:employee_role).and_return(employee_role)
      allow(benefit_group).to receive(:reference_plan).and_return(reference_plan)
      allow(hbx_enrollment).to receive(:build_plan_premium).and_return(true)
      allow(hbx_enrollment).to receive(:census_employee).and_return(census_employee)
      allow(subject).to receive(:employee_mid_year_plan_change).and_return(true)
      allow(sponsored_benefit).to receive(:rate_schedule_date).and_return(rate_schedule_date)
      allow(HbxEnrollmentSponsoredCostCalculator).to receive(:new).with(hbx_enrollment).and_return(cost_calculator)
      allow(cost_calculator).to receive(:groups_for_products).with([product]).and_return([member_group])
    end

    it "returns http success" do
      sign_in(user)
      get :receipt, id: "id"
      expect(response).to have_http_status(:success)
    end

    it "should get employer_profile" do
      allow(hbx_enrollment).to receive(:employee_role_id).and_return(nil)
      allow(hbx_enrollment).to receive(:is_shop?).and_return(true)
      allow(hbx_enrollment).to receive(:coverage_kind).and_return('health')
      allow(hbx_enrollment).to receive(:employer_profile).and_return(abc_profile)
      sign_in(user)
      get :receipt, id: "id"
      expect(assigns(:employer_profile)).to eq abc_profile
    end
  end

  context "GET thankyou" do
    let(:member_group) { double("MEMBERGROUP")}

    before do
      allow(user).to receive(:person).and_return(person)
      allow(HbxEnrollment).to receive(:find).with("id").and_return(hbx_enrollment)
      allow(BenefitMarkets::Products::Product).to receive(:find).with("plan_id").and_return(product)
      allow(hbx_enrollment).to receive(:product).and_return(product)
      allow(hbx_enrollment).to receive(:rating_area).and_return(rating_area)
      allow(hbx_enrollment).to receive(:is_shop?).and_return(false)
      allow(hbx_enrollment).to receive(:benefit_group).and_return(benefit_group)
      allow(benefit_group).to receive(:reference_plan).and_return(reference_plan)
      allow(PlanCostDecorator).to receive(:new).and_return(true)
      allow(person).to receive(:primary_family).and_return(family)
      allow(hbx_enrollment).to receive(:can_complete_shopping?).and_return(true)
      allow(hbx_enrollment).to receive(:employee_role).and_return(double)
      allow(hbx_enrollment).to receive(:is_special_enrollment?).and_return false
      allow(hbx_enrollment).to receive(:can_select_coverage?).and_return(true)
      allow(hbx_enrollment).to receive(:build_plan_premium).and_return(true)
      allow(hbx_enrollment).to receive(:set_special_enrollment_period).and_return(true)
      allow(hbx_enrollment).to receive(:reset_dates_on_previously_covered_members).and_return(true)
      allow(hbx_enrollment).to receive(:sponsored_benefit).and_return(sponsored_benefit)
      allow(sponsored_benefit).to receive(:rate_schedule_date).and_return(rate_schedule_date)
      allow(HbxEnrollmentSponsoredCostCalculator).to receive(:new).with(hbx_enrollment).and_return(cost_calculator)
      allow(cost_calculator).to receive(:groups_for_products).with([product]).and_return([member_group])
    end

    it "returns http success" do
      sign_in(user)
      get :thankyou, id: "id", plan_id: "plan_id"
      expect(response).to have_http_status(:success)
    end

    it "should be enrollable" do
      sign_in(user)
      get :thankyou, id: "id", plan_id: "plan_id"
      expect(assigns(:enrollable)).to be_truthy
    end

    it "should be waivable" do
      sign_in(user)
      get :thankyou, id: "id", plan_id: "plan_id"
      expect(assigns(:waivable)).to be_truthy
    end

    it "should get employer_profile" do
      allow(hbx_enrollment).to receive(:is_shop?).and_return(true)
      allow(hbx_enrollment).to receive(:coverage_kind).and_return('health')
      allow(hbx_enrollment).to receive(:employer_profile).and_return(abc_profile)
      sign_in(user)
      get :thankyou, id: "id", plan_id: "plan_id"
      expect(assigns(:employer_profile)).to eq abc_profile
    end

    it "returns http success as BROKER" do
      person = create(:person)
      f=FactoryGirl.create(:family,:family_members=>[{:is_primary_applicant=>true, :is_active=>true, :person_id => person.id}])
      current_broker_user = FactoryGirl.create(:user, :roles => ['broker_agency_staff'],
                                               :person => person )
      current_broker_user.person.broker_role = BrokerRole.new({:broker_agency_profile_id => 99})
      allow(session).to receive(:[]).and_return(person.id.to_s)
      sign_in(current_broker_user)
      get :thankyou, id: "id", plan_id: "plan_id"
      expect(response).to have_http_status(:success)
    end

    context "when not eligible to complete shopping" do
      before do
        allow(hbx_enrollment).to receive(:can_complete_shopping?).and_return(false)
      end

      it "should not be enrollable" do
        sign_in(user)
        get :thankyou, id: "id", plan_id: "plan_id"
        expect(assigns(:enrollable)).to be_falsey
      end

      it "should not be waivable" do
        sign_in(user)
        get :thankyou, id: "id", plan_id: "plan_id"
        expect(assigns(:waivable)).to be_falsey
      end

      it "should update session" do
        sign_in(user)
        get :thankyou, id: "id", plan_id: "plan_id", elected_aptc: "50"
        expect(session[:elected_aptc]).to eq 50
      end
    end

    # context "for qualify_qle_notice" do
    #   it "should get error msg" do
    #     allow(hbx_enrollment).to receive(:can_select_coverage?).and_return false
    #     sign_in(user)
    #     get :thankyou, id: "id", plan_id: "plan_id"
    #     expect(flash[:error]).to include("In order to purchase benefit coverage, you must be in either an Open Enrollment or Special Enrollment period. ")
    #   end
    #
    #   it "should not get error msg" do
    #     allow(hbx_enrollment).to receive(:can_select_coverage?).and_return true
    #     sign_in(user)
    #     get :thankyou, id: "id", plan_id: "plan_id"
    #     expect(flash[:error]).to eq nil
    #   end
    # end
  end

  context "GET print_waiver" do
    it "should return hbx_enrollment to print waiver" do
      allow(user).to receive(:person).and_return(person)
      allow(HbxEnrollment).to receive(:find).with("id").and_return(hbx_enrollment)
      sign_in(user)
      get :print_waiver, id: "id"
      expect(response).to have_http_status(:success)
    end
  end

  context "POST terminate" do
    before do
      allow(HbxEnrollment).to receive(:find).with("hbx_id").and_return(hbx_enrollment)
      allow(hbx_enrollment).to receive(:may_schedule_coverage_termination?).and_return(true)
      allow(hbx_enrollment).to receive(:schedule_coverage_termination!).and_return(true)
      allow(person).to receive(:primary_family).and_return(family)
      allow(hbx_enrollment).to receive(:rating_area).and_return(rating_area)
      allow(hbx_enrollment).to receive(:sponsored_benefit).and_return(sponsored_benefit)
      allow(sponsored_benefit).to receive(:rate_schedule_date).and_return(rate_schedule_date)
      allow(HbxEnrollmentSponsoredCostCalculator).to receive(:new).with(hbx_enrollment).and_return(cost_calculator)
      sign_in user
    end

    it "returns http success" do
      post :terminate, id: "hbx_id"
      expect(response).to be_redirect
    end

    it "goes back" do
      request.env["HTTP_REFERER"] = terminate_insured_plan_shopping_url(1)
      allow(hbx_enrollment).to receive(:may_schedule_coverage_termination?).and_return(false)
      post :terminate, id: "hbx_id"
      expect(response).to redirect_to(:back)
    end

    it "should record termination submitted date on terminate of hbx_enrollment" do
      expect(hbx_enrollment.termination_submitted_on).to eq nil
      post :terminate, id: "hbx_id"
      expect(hbx_enrollment.termination_submitted_on).to be_within(1.second).of TimeKeeper.datetime_of_record
      expect(response).to be_redirect
    end
  end

  context "GET waive" do
    before :each do
      allow(HbxEnrollment).to receive(:find).with("hbx_id").and_return(hbx_enrollment)
      sign_in user
    end

    it "should get success flash message" do
      allow(hbx_enrollment).to receive(:waive_coverage_by_benefit_group_assignment).with("Because").and_return(true)
      get :waive, id: "hbx_id", waiver_reason: "Because"
      expect(flash[:notice]).to eq "Waive Coverage Successful"
      expect(response).to be_redirect
    end

    it "should get failure flash message" do
      allow(hbx_enrollment).to receive(:waive_coverage_by_benefit_group_assignment).with("Because").and_raise(StandardError.new("WAIVE FAILED"))
      get :waive, id: "hbx_id", waiver_reason: "Because"
      expect(flash[:alert]).to eq "Waive Coverage Failed"
      expect(response).to be_redirect
    end
  end

  context "GET show" do
    let(:product_1)   { FactoryGirl.create(:benefit_markets_products_health_products_health_product) }
    let(:product_2)   { FactoryGirl.create(:benefit_markets_products_health_products_health_product) }
    let(:product_3)   { FactoryGirl.create(:benefit_markets_products_health_products_health_product) }
    let(:products) {[hbx_enrollment.sponsored_benefit.reference_product]}
    let(:coverage_kind){"health"}
    let(:cost_calculator) { HbxEnrollmentSponsoredCostCalculator.new(hbx_enrollment) }
    let(:product_groups) { products }
    let(:family_group_enrollment) do
      BenefitSponsors::Enrollments::GroupEnrollment.new(
          member_enrollments: [],
          rate_schedule_date: '',
          coverage_start_on: '',
          previous_product: nil,
          product: products,
          rating_area: '',
          product_cost_total: ''
      )
    end
    let(:member_group) do
      ::BenefitSponsors::Members::MemberGroup.new(
          group_enrollment: [family_group_enrollment]
      )
    end
    let!(:update_sponsored_benefit) { sponsored_benefit.update_attributes(product_package_kind: "single_product") }

    before :each do
      allow(HbxEnrollmentSponsoredCostCalculator).to receive(:new).with(hbx_enrollment).and_return(cost_calculator)
      allow(HbxEnrollment).to receive(:find).with("hbx_id").and_return(hbx_enrollment)
      allow(hbx_enrollment).to receive(:household).and_return(household)
      allow(family).to receive(:family_members).and_return(family_members)
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:primary_family).and_return(family)
      allow(family).to receive(:enrolled_hbx_enrollments).and_return([])
      allow(benefit_group).to receive(:plan_option_kind).and_return("single_plan")
      allow(hbx_enrollment).to receive(:can_complete_shopping?).and_return(true)
      allow(hbx_enrollment).to receive(:effective_on).and_return(Date.new(2015))
      allow(hbx_enrollment).to receive(:family).and_return(family)
      allow(hbx_enrollment).to receive(:coverage_kind).and_return('health')
      allow(hbx_enrollment).to receive(:sponsored_benefit).and_return(sponsored_benefit)
      allow(cost_calculator).to receive(:groups_for_products).with(products).and_return(product_groups)
      allow_any_instance_of(Insured::PlanShoppingsController).to receive(:sort_member_groups).with(product_groups).and_return(member_group)
      allow(hbx_enrollment).to receive(:product).and_return(product_1)
      allow(sponsored_benefit).to receive(:rate_schedule_date).and_return(rate_schedule_date)
      allow(HbxEnrollmentSponsoredCostCalculator).to receive(:new).with(hbx_enrollment).and_return(cost_calculator)
      sign_in user
    end

    context "normal" do
      before :each do
        allow(hbx_enrollment).to receive(:can_waive_enrollment?).and_return(true)
        get :show, id: "hbx_id"
      end

      it "should be success" do
        expect(response).to have_http_status(:success)
      end

      it "should be waivable" do
        expect(assigns(:waivable)).to be_truthy
      end
    end

    context "when not eligible to complete shopping" do
      let(:group_enrollment) {BenefitSponsors::Enrollments::GroupEnrollment.new(product: product, member_enrollments:[member_enrollment], product_cost_total:'')}

      before :each do
        allow(hbx_enrollment).to receive(:can_waive_enrollment?).and_return(false)
        allow(user).to receive(:person).and_return(person)
        allow(hbx_enrollment).to receive(:sponsored_benefit).and_return(sponsored_benefit)
        allow(person).to receive(:primary_family).and_return(family)
        allow(family).to receive(:enrolled_hbx_enrollments).and_return([])
        allow(hbx_enrollment).to receive(:can_complete_shopping?).and_return(false)
        allow(hbx_enrollment).to receive(:coverage_kind).and_return('health')
        get :show, id: "hbx_id"
      end

      it "should not be waivable" do
        expect(assigns(:waivable)).to be_falsey
      end
    end

    if ExchangeTestingConfigurationHelper.individual_market_is_enabled?
      context "when user has_active_consumer_role" do
        let(:tax_household) {double("TaxHousehold")}
        let(:family) { FactoryGirl.build(:individual_market_family) }
        let(:person) {double("Person",primary_family: family, has_active_consumer_role?: true)}
        let(:user) {double("user",person: person)}

        before do
          allow(hbx_enrollment).to receive(:coverage_kind).and_return('health')
          allow(hbx_enrollment).to receive(:is_shop?).and_return(false)
          allow(hbx_enrollment).to receive(:is_coverall?).and_return(false)
          allow(hbx_enrollment).to receive(:decorated_elected_plans).and_return([])
        end

        context "with tax_household" do
          before :each do
            allow(family).to receive(:latest_household).and_return(household)
            allow(household).to receive(:latest_active_tax_household_with_year).and_return tax_household
            allow(tax_household).to receive(:total_aptc_available_amount_for_enrollment).and_return(111)
            allow(family).to receive(:enrolled_hbx_enrollments).and_return([])
            allow(person).to receive(:active_employee_roles).and_return []
            allow(person).to receive(:employee_roles).and_return []
            allow(hbx_enrollment).to receive(:kind).and_return 'individual'
            get :show, id: "hbx_id"
          end

          it "should get max_aptc" do
            expect(assigns(:max_aptc)).to eq 111
          end

          it "should get default selected_aptc_pct" do
            expect(assigns(:elected_aptc)).to eq 111*0.85
          end
        end

        context "without tax_household" do
          before :each do
            allow(household).to receive(:latest_active_tax_household_with_year).and_return nil
            allow(family).to receive(:enrolled_hbx_enrollments).and_return([])
            allow(person).to receive(:active_employee_roles).and_return []
            allow(person).to receive(:employee_roles).and_return []
            get :show, id: "hbx_id"
          end

          it "should get max_aptc" do
            expect(session[:max_aptc]).to eq 0
          end

          it "should get default selected_aptc" do
            expect(session[:elected_aptc]).to eq 0
          end
        end

        context "without tax_household when has aptc session" do
          before :each do
            allow(household).to receive(:latest_active_tax_household_with_year).and_return nil
            allow(family).to receive(:enrolled_hbx_enrollments).and_return([])
            allow(person).to receive(:active_employee_roles).and_return []
            allow(person).to receive(:employee_roles).and_return []
            session[:max_aptc] = 100
            session[:elected_aptc] = 80
            get :show, id: "hbx_id"
          end

          it "should get max_aptc" do
            expect(session[:max_aptc]).to eq 0
          end

          it "should get default selected_aptc" do
            expect(session[:elected_aptc]).to eq 0
          end
        end

        context "with tax_household and plan shopping in shop market" do
          before :each do
            allow(household).to receive(:latest_active_tax_household_with_year).and_return tax_household
            allow(tax_household).to receive(:total_aptc_available_amount_for_enrollment).and_return(111)
            allow(family).to receive(:enrolled_hbx_enrollments).and_return([])
            allow(person).to receive(:active_employee_roles).and_return []
            allow(person).to receive(:employee_roles).and_return []
            allow(hbx_enrollment).to receive(:coverage_kind).and_return 'health'
            allow(hbx_enrollment).to receive(:kind).and_return 'shop'
            allow_any_instance_of(Services::CheckbookServices::PlanComparision).to receive(:generate_url).and_return("http://temp.url")
            get :show, id: "hbx_id"
          end

          it "should get max_aptc" do
            expect(session[:max_aptc]).to eq 0
          end

          it "should get default selected_aptc_pct" do
            expect(session[:elected_aptc]).to eq 0
          end
        end
      end
    end
  end
end