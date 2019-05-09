require 'rails_helper'

RSpec.describe Insured::FamiliesController, dbclean: :after_each do
  context "set_current_user with no person" do
    let(:user) { FactoryGirl.create(:user, person: person) }
    let(:person) { FactoryGirl.create(:person, :with_consumer_role) }
    let(:family) { FactoryGirl.create(:family, :with_primary_family_member) }
    let!(:individual_market_transition) { FactoryGirl.create(:individual_market_transition, person: person) }


    before :each do
      sign_in user
    end

    it "should assigns the family if user is hbx_staff and dependent consumer" do
      get :home, {:family => family.id.to_s}
      expect(assigns(:family)).to eq family
    end

    it "should redirect" do
      get :home, {:family => family.id}
      expect(response).to be_redirect
    end
  end

  context "set_current_user  as agent" do
    let(:user) { double("User", last_portal_visited: "test.com", id: 77, email: 'x@y.com', person: person) }
    let(:person) { FactoryGirl.create(:person) }

    it "should raise the error on invalid person_id" do
      allow(session).to receive(:[]).and_return(33)
      allow(person).to receive(:agent?).and_return(true)
      expect{get :home}.to raise_error(ArgumentError)
    end
  end
end

RSpec.describe Insured::FamiliesController, dbclean: :after_each do

  let(:hbx_enrollments) { double("HbxEnrollment") }
  let(:user) { FactoryGirl.create(:user) }
  let(:person) { double("Person", id: "test", addresses: [], no_dc_address: false, is_homeless: false, is_temporarily_out_of_state: false, has_active_consumer_role?: false, has_active_employee_role?: true, no_dc_address_reason: "" , is_consumer_role_active?: false) }
  let(:family) { instance_double(Family, active_household: household, :model_name => "Family") }
  let(:household) { double("HouseHold", hbx_enrollments: hbx_enrollments) }
  let(:addresses) { [double] }
  let(:family_members) { [double("FamilyMember")] }
  let(:employee_roles) { [double("EmployeeRole")] }
  let(:resident_role) { FactoryGirl.create(:resident_role) }
  let(:consumer_role) { double("ConsumerRole", bookmark_url: "/families/home") }
  # let(:coverage_wavied) { double("CoverageWavied") }
  let(:qle) { FactoryGirl.create(:qualifying_life_event_kind, pre_event_sep_in_days: 30, post_event_sep_in_days: 0) }
  let(:sep) { double("SpecialEnrollmentPeriod") }

  before :each do
    allow(hbx_enrollments).to receive(:size).and_return(1)
    allow(hbx_enrollments).to receive(:order).and_return(hbx_enrollments)
    allow(hbx_enrollments).to receive(:waived).and_return([])
    allow(hbx_enrollments).to receive(:any?).and_return(false)
    allow(user).to receive(:person).and_return(person)
    allow(user).to receive(:last_portal_visited).and_return("test.com")
    allow(person).to receive(:primary_family).and_return(family)
    allow(family).to receive_message_chain("family_members.active").and_return(family_members)
    allow(person).to receive(:consumer_role).and_return(consumer_role)
    allow(person).to receive(:active_employee_roles).and_return(employee_roles)
    allow(person).to receive(:is_resident_role_active?).and_return(true)
    allow(person).to receive(:resident_role).and_return(resident_role)
    allow(consumer_role).to receive(:bookmark_url=).and_return(true)
    sign_in(user)
  end

  describe "GET home" do
    let(:family_access_policy) { instance_double(FamilyPolicy, :show? => true) }

    before :each do
      allow(FamilyPolicy).to receive(:new).with(user, family).and_return(family_access_policy)
      allow(family).to receive(:enrollments).and_return(hbx_enrollments)
      allow(family).to receive(:enrollments_for_display).and_return(hbx_enrollments)
      allow(family).to receive(:waivers_for_display).and_return(hbx_enrollments)
      allow(family).to receive(:coverage_waived?).and_return(false)
      allow(family).to receive(:latest_active_sep).and_return sep
      allow(hbx_enrollments).to receive(:active).and_return(hbx_enrollments)
      allow(hbx_enrollments).to receive(:changing).and_return([])
      allow(user).to receive(:has_employee_role?).and_return(true)
      allow(user).to receive(:has_consumer_role?).and_return(true)
      allow(user).to receive(:last_portal_visited=).and_return("test.com")
      allow(user).to receive(:save).and_return(true)
      allow(user).to receive(:person).and_return(person)
      allow(person).to receive(:consumer_role).and_return(consumer_role)
      allow(person).to receive(:addresses).and_return(addresses)
      allow(person).to receive(:has_multiple_roles?).and_return(true)
      allow(consumer_role).to receive(:save!).and_return(true)

      allow(family).to receive(:_id).and_return(true)
      allow(hbx_enrollments).to receive(:_id).and_return(true)
      allow(hbx_enrollments).to receive(:each).and_return(hbx_enrollments)
      allow(hbx_enrollments).to receive(:reject).and_return(hbx_enrollments)
      allow(hbx_enrollments).to receive(:inject).and_return(hbx_enrollments)
      allow(hbx_enrollments).to receive(:compact).and_return(hbx_enrollments)

      session[:portal] = "insured/families"
    end

    context "#check_for_address_info" do
      before :each do
        allow(person).to receive(:user).and_return(user)
        allow(user).to receive(:identity_verified?).and_return(false)
        allow(consumer_role).to receive(:identity_verified?).and_return(false)
        allow(consumer_role).to receive(:application_verified?).and_return(false)
        allow(person).to receive(:has_active_employee_role?).and_return(false)
        allow(person).to receive(:is_consumer_role_active?).and_return(true)
        allow(person).to receive(:active_employee_roles).and_return([])
        allow(person).to receive(:employee_roles).and_return([])
        allow(user).to receive(:get_announcements_by_roles_and_portal).and_return []
        allow(family).to receive(:check_for_consumer_role).and_return true
        allow(family).to receive(:active_family_members).and_return(family_members)
        sign_in user
      end

      it "should redirect to ridp page if user has not verified identity" do
        get :home
        expect(response).to redirect_to("/insured/consumer_role/ridp_agreement")
      end

      it "should redirect to edit page if user do not have addresses" do
        allow(person).to receive(:addresses).and_return []
        get :home
        expect(response).to redirect_to(edit_insured_consumer_role_path(consumer_role))
      end
    end



    context "#init_qle" do
      before :each do
        @controller = Insured::FamiliesController.new
        @qle = FactoryGirl.create(:qualifying_life_event_kind)
        allow(@controller).to receive(:set_family)
        @controller.instance_variable_set(:@person, person)
        allow(person).to receive(:user).and_return(user)
        allow(user).to receive(:identity_verified?).and_return(false)
        allow(person).to receive(:has_active_employee_role?).and_return(true)
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        allow(person).to receive(:active_employee_roles).and_return([])
        allow(person).to receive(:employee_roles).and_return([])
        allow(user).to receive(:get_announcements_by_roles_and_portal).and_return []
        allow(family).to receive(:check_for_consumer_role).and_return true
        allow(family).to receive(:active_family_members).and_return(family_members)
        sign_in user
      end
      after do
        QualifyingLifeEventKind.destroy_all
      end

      it "should return qles" do
        allow(@controller).to receive(:params).and_return({})
        expect(@controller.instance_eval { init_qualifying_life_events }).to eq ([@qle])
      end


      it "should return qles" do
        allow(@controller).to receive(:params).and_return({market: "individual_market_events"})
        expect(@controller.instance_eval { init_qualifying_life_events }).to eq ([])
      end
    end

    context "for SHOP market" do

      let(:employee_roles) { double }
      let(:employee_role) { FactoryGirl.create(:employee_role, bookmark_url: "/families/home") }
      let(:census_employee) { FactoryGirl.create(:census_employee, employee_role_id: employee_role.id) }

      before :each do
        FactoryGirl.create(:announcement, content: "msg for Employee", audiences: ['Employee'])
        allow(person).to receive(:has_active_employee_role?).and_return(true)
        allow(person).to receive(:active_employee_roles).and_return([employee_role])
        allow(person).to receive(:employee_roles).and_return([employee_role])
        allow(family).to receive(:coverage_waived?).and_return(true)
        allow(family).to receive(:active_family_members).and_return(family_members)
        allow(family).to receive(:check_for_consumer_role).and_return nil
        allow(employee_role).to receive(:census_employee_id).and_return census_employee.id
        sign_in user
        get :home
      end

      it "should be a success" do
        expect(response).to have_http_status(:success)
      end

      it "should render my account page" do
        expect(response).to render_template("home")
      end

      it "should assign variables" do
        expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
        expect(assigns(:hbx_enrollments)).to eq(hbx_enrollments)
        expect(assigns(:employee_role)).to eq(employee_role)
      end

      it "should get shop market events" do
        expect(assigns(:qualifying_life_events)).to eq QualifyingLifeEventKind.shop_market_events
      end

      it "should get announcement" do
        expect(flash.now[:warning]).to eq ["msg for Employee"]
      end
    end

    context "for IVL market" do
      let(:user) { FactoryGirl.create(:user) }
      let(:employee_roles) { double }

      before :each do
        allow(user).to receive(:idp_verified?).and_return true
        allow(user).to receive(:identity_verified?).and_return true
        allow(user).to receive(:last_portal_visited).and_return ''
        allow(person).to receive(:user).and_return(user)
        allow(person).to receive(:has_active_employee_role?).and_return(false)
        allow(person).to receive(:is_consumer_role_active?).and_return(true)
        allow(person).to receive(:active_employee_roles).and_return([])
        allow(person).to receive(:employee_roles).and_return(nil)
        allow(family).to receive(:active_family_members).and_return(family_members)
        allow(family).to receive(:check_for_consumer_role).and_return true
        sign_in user
        get :home
      end

      it "should be a success" do
        expect(response).to have_http_status(:success)
      end

      it "should render my account page" do
        expect(response).to render_template("home")
      end

      it "should assign variables" do
        expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
        expect(assigns(:hbx_enrollments)).to eq(hbx_enrollments)
        expect(assigns(:employee_role)).to be_nil
      end

      it "should get individual market events" do
        expect(assigns(:qualifying_life_events)).to eq QualifyingLifeEventKind.individual_market_events
      end

      context "who has not passed ridp" do
        let(:user) { double(identity_verified?: false, last_portal_visited: '', idp_verified?: false) }
        let(:user) { FactoryGirl.create(:user) }

        before do
          allow(user).to receive(:idp_verified?).and_return false
          allow(user).to receive(:identity_verified?).and_return false
          allow(consumer_role).to receive(:identity_verified?).and_return false
          allow(consumer_role).to receive(:application_verified?).and_return false
          allow(user).to receive(:last_portal_visited).and_return ''
          allow(person).to receive(:user).and_return(user)
          allow(person).to receive(:has_active_employee_role?).and_return(false)
          allow(person).to receive(:is_consumer_role_active?).and_return(true)
          allow(person).to receive(:active_employee_roles).and_return([])
          sign_in user
          get :home
        end

        it "should be a redirect" do
          expect(response).to have_http_status(:redirect)
        end
      end
    end

    context "for both ivl and shop" do
      let(:employee_roles) { double }
      let(:employee_role) { double("EmployeeRole", bookmark_url: "/families/home") }
      let(:enrollments) { double }
      let(:employee_role2) { FactoryGirl.create(:employee_role) }
      let(:census_employee) { FactoryGirl.create(:census_employee, employee_role_id: employee_role2.id) }

      before :each do
        sign_in user
        allow(person).to receive(:has_active_employee_role?).and_return(true)
        allow(person).to receive(:employee_roles).and_return(employee_roles)
        allow(person.employee_roles).to receive(:last).and_return(employee_role)
        allow(person).to receive(:active_employee_roles).and_return(employee_roles)
        allow(employee_roles).to receive(:first).and_return(employee_role)
        allow(employee_roles).to receive(:count).and_return(1)
        allow(person).to receive(:is_consumer_role_active?).and_return(true)
        allow(employee_roles).to receive(:active).and_return([employee_role])
        allow(family).to receive(:coverage_waived?).and_return(true)
        allow(hbx_enrollments).to receive(:waived).and_return([waived_hbx])
        allow(family).to receive(:enrollments).and_return(enrollments)
        allow(enrollments).to receive(:order).and_return([display_hbx])
        allow(family).to receive(:enrollments_for_display).and_return([{"hbx_enrollment"=>{"_id"=>display_hbx.id}}])
        allow(family).to receive(:check_for_consumer_role).and_return true
        allow(controller).to receive(:update_changing_hbxs).and_return(true)
        allow(employee_role).to receive(:census_employee_id).and_return census_employee.id
      end

      context "with waived_hbx when display_hbx is employer_sponsored" do
        let(:waived_hbx) { HbxEnrollment.new(kind: 'employer_sponsored', effective_on: TimeKeeper.date_of_record) }
        let(:display_hbx) { HbxEnrollment.new(kind: 'employer_sponsored', aasm_state: 'coverage_selected', effective_on: TimeKeeper.date_of_record) }
        let(:employee_role) { FactoryGirl.create(:employee_role) }
        let(:census_employee) { FactoryGirl.create(:census_employee, employee_role_id: employee_role.id) }
        before :each do
          allow(family).to receive(:waivers_for_display).and_return([{"hbx_enrollment"=>{"_id"=>waived_hbx.id}}])
          allow(family).to receive(:active_family_members).and_return(family_members)
          allow(employee_role).to receive(:census_employee_id).and_return census_employee.id
          get :home
        end
        it "should be a success" do
          expect(response).to have_http_status(:success)
        end

        it "should render my account page" do
          expect(response).to render_template("home")
        end

        it "should assign variables" do
          expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
          expect(assigns(:hbx_enrollments)).to eq([display_hbx])
          expect(assigns(:employee_role)).to eq(employee_role)
        end
      end

      context "with waived_hbx when display_hbx is individual" do
        let(:waived_hbx) { HbxEnrollment.new(kind: 'employer_sponsored', effective_on: TimeKeeper.date_of_record) }
        let(:display_hbx) { HbxEnrollment.new(kind: 'individual', aasm_state: 'coverage_selected', effective_on: TimeKeeper.date_of_record) }
        let(:employee_role) { FactoryGirl.create(:employee_role) }
        let(:census_employee) { FactoryGirl.create(:census_employee, employee_role_id: employee_role.id) }
        before :each do
          allow(family).to receive(:waivers_for_display).and_return([{"hbx_enrollment"=>{"_id"=>waived_hbx.id}}])
          allow(family).to receive(:active_family_members).and_return(family_members)
          allow(employee_role).to receive(:census_employee_id).and_return census_employee.id
          get :home
        end
        it "should be a success" do
          expect(response).to have_http_status(:success)
        end

        it "should render my account page" do
          expect(response).to render_template("home")
        end

        it "should assign variables" do
          expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
          expect(assigns(:hbx_enrollments)).to eq([display_hbx])
          expect(assigns(:employee_role)).to eq(employee_role)
        end
      end
    end
  end

  describe "GET verification" do
    let(:person) {FactoryGirl.create(:person, :with_consumer_role)}
    let(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: person) }
    let(:user){ FactoryGirl.create(:user, person: person) }
    let(:family_member) { FamilyMember.new(:person => person) }

    before :each do
      allow(person).to receive(:primary_family).and_return (family)
      allow(family). to receive(:has_active_consumer_family_members). and_return([family_member])
      allow(person).to receive(:is_consumer_role_active?).and_return true
    end

    it "should be success" do
      get :verification
      expect(response).to have_http_status(:success)
    end

    it "renders verification template" do
      get :verification
      expect(response).to render_template("verification")
    end

    it "assign variables" do
      get :verification
      expect(assigns(:family_members)).to be_an_instance_of(Array)
      expect(assigns(:family_members)).to eq([family_member])
    end
  end

  describe "GET manage_family" do
    let(:employee_roles) { double }
    let(:employee_role) { [double("EmployeeRole")] }

    before :each do
      allow(person).to receive(:active_employee_roles).and_return([employee_role])
      allow(family).to receive(:coverage_waived?).and_return(true)
      allow(family).to receive(:active_family_members).and_return(family_members)
    end

    it "should be a success" do
      allow(person).to receive(:has_multiple_roles?).and_return(false)
      get :manage_family
      expect(response).to have_http_status(:success)
    end

    it "should render manage family section" do
      allow(person).to receive(:has_multiple_roles?).and_return(false)
      get :manage_family
      expect(response).to render_template("manage_family")
    end

    it "should assign variables" do
      allow(person).to receive(:has_multiple_roles?).and_return(false)
      get :manage_family
      expect(assigns(:qualifying_life_events)).to be_an_instance_of(Array)
      expect(assigns(:family_members)).to eq(family_members)
    end

    it "assigns variable to change QLE to IVL flow" do
      allow(person).to receive(:has_multiple_roles?).and_return(true)
      get :manage_family, market: "shop_market_events"
      expect(assigns(:manually_picked_role)).to eq "shop_market_events"
    end

    it "assigns variable to change QLE to Employee flow" do
      allow(person).to receive(:has_multiple_roles?).and_return(true)
      get :manage_family, market: "individual_market_events"
      expect(assigns(:manually_picked_role)).to eq "individual_market_events"
    end

    it "doesn't assign the variable to show different flow for QLE" do
      allow(person).to receive(:has_multiple_roles?).and_return(false)
      get :manage_family, market: "shop_market_events"
      expect(assigns(:manually_picked_role)).to eq nil
    end
  end

  describe "GET personal" do
    before :each do
      allow(family).to receive(:active_family_members).and_return(family_members)
      sign_in user
      get :personal
    end

    it "should be a success" do
      expect(response).to have_http_status(:success)
    end

    it "should render person edit page" do
      expect(response).to render_template("personal")
    end

    it "should assign variables" do
      expect(assigns(:family_members)).to eq(family_members)
    end
  end

  describe "GET inbox" do
    before :each do
      allow(family).to receive(:active_family_members).and_return(family_members)
      get :inbox
    end

    it "should be a success" do
      expect(response).to have_http_status(:success)
    end

    it "should render inbox" do
      expect(response).to render_template("inbox")
    end

    it "should assign variables" do
      expect(assigns(:folder)).to eq("Inbox")
    end
  end


  describe "GET find_sep" do
    let(:user) { double(identity_verified?: true, idp_verified?: true) }
    let(:employee_roles) { double }
    let(:employee_role) { [double("EmployeeRole")] }
    let(:special_enrollment_period) {[double("SpecialEnrollmentPeriod")]}

    before :each do
      allow(person).to receive(:user).and_return(user)
      allow(person).to receive(:has_active_employee_role?).and_return(false)
      allow(person).to receive(:is_consumer_role_active?).and_return(true)
      allow(person).to receive(:has_multiple_roles?).and_return(true)
      allow(user).to receive(:has_hbx_staff_role?).and_return(false)
      allow(person).to receive(:active_employee_roles).and_return(employee_role)
      allow(family).to receive_message_chain("special_enrollment_periods.where").and_return([special_enrollment_period])
      get :find_sep, hbx_enrollment_id: "2312121212", change_plan: "change_plan"
    end

    it "should be a redirect to edit insured person" do
      expect(response).to have_http_status(:redirect)
    end

    context "with a person with an address" do
      let(:person) { double("Person", id: "test", addresses: true, no_dc_address: false, is_homeless: false, is_temporarily_out_of_state: false) }

      it "should be a success" do
        expect(response).to have_http_status(:success)
      end

      it "should render my account page" do
        expect(response).to render_template("find_sep")
      end

      it "should assign variables" do
        expect(assigns(:hbx_enrollment_id)).to eq("2312121212")
        expect(assigns(:change_plan)).to eq('change_plan')
      end
    end
  end

  describe "POST record_sep", dbclean: :after_each do

    before :each do
      date = TimeKeeper.date_of_record - 10.days
      @qle = FactoryGirl.create(:qualifying_life_event_kind, :effective_on_event_date)
      @family = FactoryGirl.build(:family, :with_primary_family_member)
      special_enrollment_period = @family.special_enrollment_periods.new(effective_on_kind: date)
      special_enrollment_period.selected_effective_on = date.strftime('%m/%d/%Y')
      special_enrollment_period.qualifying_life_event_kind = @qle
      special_enrollment_period.qle_on = date.strftime('%m/%d/%Y')
      special_enrollment_period.save
      allow(person).to receive(:primary_family).and_return(@family)
      allow(person).to receive(:hbx_staff_role).and_return(nil)
    end

    context 'when its initial enrollment' do
      before :each do
        post :record_sep, qle_id: @qle.id, qle_date: Date.today
      end

      it "should redirect" do
        special_enrollment_period = @family.special_enrollment_periods.last
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_insured_group_selection_path({person_id: person.id, consumer_role_id: person.consumer_role.try(:id), enrollment_kind: 'sep', effective_on_date: special_enrollment_period.effective_on, qle_id: @qle.id}))
      end
    end

    context 'when its change of plan' do

      before :each do
        allow(@family).to receive(:enrolled_hbx_enrollments).and_return([double])
        post :record_sep, qle_id: @qle.id, qle_date: Date.today
      end

      it "should redirect with change_plan parameter" do
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(new_insured_group_selection_path({person_id: person.id, consumer_role_id: person.consumer_role.try(:id), change_plan: 'change_plan', enrollment_kind: 'sep', qle_id: @qle.id}))
      end
    end
  end

  describe "qle kinds" do
    before(:each) do
      sign_in(user)
      @qle = FactoryGirl.create(:qualifying_life_event_kind)
      @family = FactoryGirl.build(:family, :with_primary_family_member)
      allow(person).to receive(:primary_family).and_return(@family)
      allow(person).to receive(:resident_role?).and_return(false)
    end

    context "#check_marriage_reason" do
      it "renders the check_marriage reason template" do
        xhr :get, 'check_marriage_reason', :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :qle_id => @qle.id, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:check_marriage_reason)
        expect(assigns(:qle_date_calc)).to eq assigns(:qle_date) - Settings.aca.qle.with_in_sixty_days.days
      end
    end

    context "#check_move_reason" do
      it "renders the 'check_move_reason' template" do
        xhr :get, 'check_move_reason', :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :qle_id => @qle.id, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:check_move_reason)
        expect(assigns(:qle_date_calc)).to eq assigns(:qle_date) - Settings.aca.qle.with_in_sixty_days.days
      end

      it "returns qualified_date as true" do
        xhr :get, 'check_move_reason', :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :qle_id => @qle.id, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(assigns['qualified_date']).to eq(true)
      end

      it "returns qualified_date as false" do
        xhr :get, 'check_move_reason', :date_val => (TimeKeeper.date_of_record + 31.days).strftime("%m/%d/%Y"), :qle_id => @qle.id, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(assigns['qualified_date']).to eq(false)
      end
    end

    context "#check_insurance_reason" do
      it "renders the 'check_insurance_reason' template" do
        xhr :get, 'check_insurance_reason', :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :qle_id => @qle.id, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:check_insurance_reason)
      end

      it "returns qualified_date as true" do
        xhr :get, 'check_insurance_reason', :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :qle_id => @qle.id, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(assigns['qualified_date']).to eq(true)
      end

      it "returns qualified_date as false" do
        xhr :get, 'check_insurance_reason', :date_val => (TimeKeeper.date_of_record + 31.days).strftime("%m/%d/%Y"), :qle_id => @qle.id, :format => 'js'
        expect(response).to have_http_status(:success)
        expect(assigns['qualified_date']).to eq(false)
      end
    end
  end

  describe "GET check_qle_date" do

    before(:each) do
      sign_in(user)
      allow(person).to receive(:resident_role?).and_return(false)
    end

    it "renders the 'check_qle_date' template" do
      xhr :get, 'check_qle_date', :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :format => 'js'
      expect(response).to have_http_status(:success)
    end

    describe "with valid params" do
      it "returns qualified_date as true" do
        xhr :get, 'check_qle_date', :date_val => (TimeKeeper.date_of_record - 10.days).strftime("%m/%d/%Y"), :format => 'js'
        expect(response).to have_http_status(:success)
        expect(assigns['qualified_date']).to eq(true)
      end
    end

    describe "with invalid params" do
      it "returns qualified_date as false for invalid future date" do
        xhr :get, 'check_qle_date', {:date_val => (TimeKeeper.date_of_record + 31.days).strftime("%m/%d/%Y"), :format => 'js'}
        expect(assigns['qualified_date']).to eq(false)
      end

      it "returns qualified_date as false for invalid past date" do
        xhr :get, 'check_qle_date', {:date_val => (TimeKeeper.date_of_record - 61.days).strftime("%m/%d/%Y"), :format => 'js'}
        expect(assigns['qualified_date']).to eq(false)
      end
    end

    context "qle event when person has dual roles" do
      let(:organization) { FactoryGirl.create(:organization, :with_active_plan_year) }
      let(:employer_profile) { organization.employer_profile }
      let(:notice_event1) {"sep_denial_notice_for_ee_active_on_single_roster"}
      let(:notice_event2) {"sep_denial_notice_for_ee_active_on_multiple_rosters"}

      before :each do
        allow(person).to receive(:user).and_return(user)
        allow(person).to receive(:has_active_employee_role?).and_return(true)
        allow(person).to receive(:has_multiple_active_employers?).and_return(false)
        allow(person).to receive(:has_active_consumer_role?).and_return(true)
        allow(person).to receive(:is_consumer_role_active?).and_return(true)
        @qle = FactoryGirl.create(:qualifying_life_event_kind)
        @family = FactoryGirl.build(:family, :with_primary_family_member)
        allow(person).to receive(:primary_family).and_return(@family)
        allow(employee_roles.first).to receive(:employer_profile).and_return(employer_profile)
      end

      it "future_qualified_date return true/false when qle market kind is shop" do
        date = TimeKeeper.date_of_record.strftime("%m/%d/%Y")
        xhr :get, :check_qle_date, date_val: date, qle_id: qle.id, format: :js
        expect(response).to have_http_status(:success)
        expect(assigns(:future_qualified_date)).to eq(false)
      end

      it "trigger notice_event1 for unqualified date when qle market kind is shop and employee active on single roster" do
        qle = FactoryGirl.create(:qualifying_life_event_kind, market_kind: 'shop')
        date = TimeKeeper.date_of_record.next_month.strftime("%m/%d/%Y")
        today = TimeKeeper.date_of_record.strftime("%m/%d/%Y")
        expect(controller).to receive(:trigger_notice_observer).with(person.active_employee_roles.first, employer_profile.plan_years.first, notice_event1, {:qle_title=> @qle.title, :qle_reporting_deadline=> today, :qle_event_on=> date})
        xhr :get, :check_qle_date, date_val: date, qle_id: qle.id, format: :js
      end

      it 'should trigger notice_event2 when employee active on multiple rosters' do
        allow(person).to receive(:has_multiple_active_employers?).and_return(true)
        qle = FactoryGirl.create(:qualifying_life_event_kind, market_kind: 'shop')
        date = TimeKeeper.date_of_record.next_month.strftime("%m/%d/%Y")
        today = TimeKeeper.date_of_record.strftime("%m/%d/%Y")
        expect(controller).to receive(:trigger_notice_observer).with(person.active_employee_roles.first, employer_profile.plan_years.first, notice_event2, {:qle_title=> @qle.title, :qle_reporting_deadline=> today, :qle_event_on=> date})
        xhr :get, :check_qle_date, date_val: date, qle_id: qle.id, format: :js
      end

      it "future_qualified_date should return nil when qle market kind is indiviual" do
        qle = FactoryGirl.build(:qualifying_life_event_kind, market_kind: "individual")
        allow(QualifyingLifeEventKind).to receive(:find).and_return(qle)
        date = TimeKeeper.date_of_record.strftime("%m/%d/%Y")
        xhr :get, :check_qle_date, date_val: date, qle_id: qle.id, format: :js
        expect(response).to have_http_status(:success)
        expect(assigns(:future_qualified_date)).to eq(nil)
      end

      it "should not trigger sep request denial notice unqualified date  when qle market kind is individual" do
        qle = FactoryGirl.build(:qualifying_life_event_kind, market_kind: "individual")
        allow(QualifyingLifeEventKind).to receive(:find).and_return(qle)
        date = TimeKeeper.date_of_record.next_month.strftime("%m/%d/%Y")
        expect(controller).not_to receive(:trigger_notice_observer)
        xhr :get, :check_qle_date, date_val: date, qle_id: qle.id, format: :js
      end
    end



    context "GET check_qle_date" do
      let(:user) { FactoryGirl.create(:user) }
      let(:person) { FactoryGirl.build(:person) }
      let(:family) { FactoryGirl.build(:family) }
      before :each do
        allow(user).to receive(:person).and_return person
        allow(person).to receive(:primary_family).and_return family
      end

      context "normal qle event" do
        it "should return true" do
          date = TimeKeeper.date_of_record.strftime("%m/%d/%Y")
          xhr :get, :check_qle_date, date_val: date, format: :js
          expect(response).to have_http_status(:success)
          expect(assigns(:qualified_date)).to eq true
        end

        it "should return false" do
          sign_in user
          date = (TimeKeeper.date_of_record + 40.days).strftime("%m/%d/%Y")
          xhr :get, :check_qle_date, date_val: date, format: :js
          expect(response).to have_http_status(:success)
          expect(assigns(:qualified_date)).to eq false
        end
      end

      context "special qle events which can not have future date" do
        let(:organization) { FactoryGirl.create(:organization, :with_active_plan_year) }
        let(:employer_profile) { organization.employer_profile }
        let(:census_employee) { FactoryGirl.create(:census_employee, employer_profile: employer_profile) }
        let(:employee_role) { FactoryGirl.create(:employee_role, employer_profile: employer_profile, census_employee_id: census_employee.id) }

        before do
          allow(person).to receive(:active_employee_roles).and_return([employee_role])
        end

        it "should return true" do
          sign_in user
          date = (TimeKeeper.date_of_record + 8.days).strftime("%m/%d/%Y")
          xhr :get, :check_qle_date, date_val: date, qle_id: qle.id, format: :js
          expect(response).to have_http_status(:success)
          expect(assigns(:qualified_date)).to eq true
        end

        it "should return false" do
          sign_in user
          date = (TimeKeeper.date_of_record - 8.days).strftime("%m/%d/%Y")
          xhr :get, :check_qle_date, date_val: date, qle_id: qle.id, format: :js
          expect(response).to have_http_status(:success)
          expect(assigns(:qualified_date)).to eq false
        end

        it "should have effective_on_options" do
          sign_in user
          date = (TimeKeeper.date_of_record - 8.days).strftime("%m/%d/%Y")
          effective_on_options = [TimeKeeper.date_of_record, TimeKeeper.date_of_record - 10.days]
          allow(QualifyingLifeEventKind).to receive(:find).and_return(qle)
          allow(qle).to receive(:is_dependent_loss_of_coverage?).and_return(true)
          allow(qle).to receive(:employee_gaining_medicare).and_return(effective_on_options)
          xhr :get, :check_qle_date, date_val: date, qle_id: qle.id, format: :js
          expect(response).to have_http_status(:success)
          expect(assigns(:effective_on_options)).to eq effective_on_options
        end
      end
    end

    context "delete delete_consumer_broker" do
      let(:family) {FactoryGirl.build(:family)}
      before :each do
        allow(person).to receive(:hbx_staff_role).and_return(double('hbx_staff_role', permission: double('permission',modify_family: true)))
        family.broker_agency_accounts = [
            FactoryGirl.build(:broker_agency_account, family: family)
        ]
        allow(Family).to receive(:find).and_return family
        delete :delete_consumer_broker , :id => family.id
      end

      it "should delete consumer broker" do
        expect(response).to have_http_status(:redirect)
        expect(family.current_broker_agency).to be nil
      end
    end
  end

  describe "GET upload_notice_form" do
    let(:user) { FactoryGirl.create(:user, person: person, roles: ["hbx_staff"]) }
    let(:person) { FactoryGirl.create(:person) }

    before(:each) do
      sign_in(user)
    end

    it "displays the upload_notice_form view" do
      xhr :get, :upload_notice_form
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:upload_notice_form)
    end
  end

  describe "GET upload_notice", dbclean: :after_each do

    let(:consumer_role2) { FactoryGirl.create(:consumer_role) }
    let(:person2) { FactoryGirl.create(:person) }
    let(:user2) { FactoryGirl.create(:user, person: person2, roles: ["hbx_staff"]) }
    let(:file) { double }
    let(:temp_file) { double }
    let(:file_path) { File.dirname(__FILE__) }
    let(:bucket_name) { 'notices' }
    let(:doc_id) { "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket_name}#sample-key" }
    let(:subject) {"New Notice"}

    before(:each) do
      @controller = Insured::FamiliesController.new
      allow(file).to receive(:original_filename).and_return("some-filename")
      allow(file).to receive(:tempfile).and_return(temp_file)
      allow(temp_file).to receive(:path)
      allow(@controller).to receive(:set_family)
      @controller.instance_variable_set(:@person, person2)
      allow(@controller).to receive(:file_path).and_return(file_path)
      allow(@controller).to receive(:file_name).and_return("sample-filename")
      allow(@controller).to receive(:file_content_type).and_return("application/pdf")
      allow(Aws::S3Storage).to receive(:save).with(file_path, bucket_name).and_return(doc_id)
      person2.consumer_role = consumer_role2
      person2.consumer_role.gender = 'male'
      person2.save
      request.env["HTTP_REFERER"] = "/insured/families/upload_notice_form"
      sign_in(user2)
    end

    it "when successful displays 'File Saved'" do
      post :upload_notice, {:file => file, :subject=> subject}
      expect(flash[:notice]).to eq("File Saved")
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to request.env["HTTP_REFERER"]
    end

    it "when failure displays 'File not uploaded'" do
      post :upload_notice
      expect(flash[:error]).to eq("File or Subject not provided")
      expect(response).to have_http_status(:found)
      expect(response).to redirect_to request.env["HTTP_REFERER"]
    end

    context "notice_upload_secure_message" do

      let(:notice) {Document.new({ title: "file_name", creator: "hbx_staff", subject: "notice", identifier: "urn:openhbx:terms:v1:file_storage:s3:bucket:#bucket_name#key",
                                   format: "file_content_type" })}

      before do
        allow(@controller).to receive(:authorized_document_download_path).with("Person", person2.id, "documents", notice.id).and_return("/path/")
        @controller.send(:notice_upload_secure_message, notice, subject)
      end

      it "adds a message to person inbox" do
        expect(person2.inbox.messages.count).to eq (2) #1 welcome message, 1 upload notification
      end
    end

    context "notice_upload_email" do
      context "person has a consumer role" do
        context "person has chosen to receive electronic communication" do
          before do
            consumer_role2.contact_method = "Paper and Electronic communications"
          end

          it "sends the email" do
            expect(@controller.send(:notice_upload_email)).to be_a_kind_of(Mail::Message)
          end

        end

        context "person has chosen not to receive electronic communication" do
          before do
            consumer_role2.contact_method = "Only Paper communication"
          end

          it "should not sent the email" do
            expect(@controller.send(:notice_upload_email)).to be nil
          end
        end
      end

      context "person has a employee role" do
        let(:employee_role2) { FactoryGirl.create(:employee_role) }

        before do
          person2.consumer_role = nil
          person2.employee_roles = [employee_role2]
          person2.save
        end

        context "person has chosen to receive electronic communication" do
          before do
            employee_role2.contact_method = "Paper and Electronic communications"
          end

          it "sends the email" do
            expect(@controller.send(:notice_upload_email)).to be_a_kind_of(Mail::Message)
          end

        end

        context "person has chosen not to receive electronic communication" do
          before do
            employee_role2.contact_method = "Only Paper communication"
          end

          it "should not sent the email" do
            expect(@controller.send(:notice_upload_email)).to be nil
          end
        end
      end
    end
  end

  describe "GET family_member_matrix" do
    let(:person) { FactoryGirl.create(:person) }
    let(:user) { FactoryGirl.create(:user, person: person) }
    let(:person1) {FactoryGirl.create(:person)}
    let(:family1) { FactoryGirl.create(:family, :with_primary_family_member) }
    let(:family_members) {FactoryGirl.build(:family_member, family: family1, is_primary_applicant: false, is_active: true, person: person1)}

    before :each do
      controller.instance_variable_set(:@family, family1)
      allow(family).to receive(:active_family_members).and_return([family_members])
      allow(family).to receive(:build_relationship_matrix).and_return(family1.build_relationship_matrix)
      allow(family).to receive(:family_members).and_return(family1.family_members)
      matrix = family1.build_relationship_matrix
      allow(family).to receive(:find_missing_relationships).and_return({:rspec => "mock"})
      allow(family).to receive(:find_all_relationships).and_return({:rspec => "parent"})
      get :family_relationships_matrix, tab: "123"
    end

    it "should be a success" do
      expect(response).to have_http_status(:success)
    end

    it "should render my account page" do
      expect(response).to render_template("family_relationships_matrix")
    end
  end

  describe "POST transition_family_members_update" do

    before :each do
      sign_in(user)
    end

    context "should transition consumer to resident" do
      let(:consumer_person) {FactoryGirl.create(:person, :with_consumer_role)}
      let(:consumer_family) { FactoryGirl.create(:family, :with_primary_family_member, person: consumer_person) }
      let(:user){ FactoryGirl.create(:user, person: consumer_person) }
      let!(:individual_market_transition) { FactoryGirl.create(:individual_market_transition, person: consumer_person) }
      let(:qle) {FactoryGirl.create(:qualifying_life_event_kind, title: "Not eligible for marketplace coverage due to citizenship or immigration status", reason: "eligibility_failed_or_documents_not_received_by_due_date ")}

      let(:consumer_params) {
        {
            "transition_effective_date_#{consumer_person.id}" => TimeKeeper.date_of_record.to_s,
            "transition_user_#{consumer_person.id}" => consumer_person.id,
            "transition_market_kind_#{consumer_person.id}" => "resident",
            "transition_reason_#{consumer_person.id}" => "eligibility_failed_or_documents_not_received_by_due_date",
            "family_actions_id" => "family_actions_#{consumer_family.id}",
            "family" => consumer_family.id,
            "qle_id" => qle.id
        }
      }

      it "should transition people" do
        xhr :post, "transition_family_members_update", consumer_params, format: :js
        expect(response).to have_http_status(:success)
      end

      it "should transition people from consumer market to resident market" do
        expect(consumer_person.is_consumer_role_active?). to be_truthy
        xhr :post, "transition_family_members_update", consumer_params, format: :js
        consumer_person.reload
        expect(consumer_person.is_resident_role_active?). to be_truthy
        expect(consumer_person.is_consumer_role_active?). to be_falsey
      end
    end

    context "should transition resident to consumer" do
      let(:resident_person) {FactoryGirl.create(:person, :with_resident_role, :with_consumer_role)}
      let(:resident_family) { FactoryGirl.create(:family, :with_primary_family_member, person: resident_person) }
      let(:user){ FactoryGirl.create(:user, person: resident_person) }
      let!(:individual_market_transition) { FactoryGirl.create(:individual_market_transition, :resident, person: resident_person) }
      let(:qle) {FactoryGirl.create(:qualifying_life_event_kind, title: "Provided documents proving eligibility", reason: "eligibility_documents_provided ")}
      let(:resident_params) {
        {
            "transition_effective_date_#{resident_person.id}" => TimeKeeper.date_of_record.to_s,
            "transition_user_#{resident_person.id}" => resident_person.id,
            "transition_market_kind_#{resident_person.id}" => "consumer",
            "transition_reason_#{resident_person.id}" => "eligibility_documents_provided",
            "family_actions_id" => "family_actions_#{resident_family.id}",
            "family" => resident_family.id,
            "qle_id" => qle.id
        }
      }

      it "should transition people" do
        xhr :post, "transition_family_members_update", resident_params, format: :js
        expect(response).to have_http_status(:success)
      end

      it "should transition people from resident market to consumer market" do
        expect(resident_person.is_resident_role_active?). to be_truthy
        xhr :post, "transition_family_members_update", resident_params, format: :js
        resident_person.reload
        expect(resident_person.is_consumer_role_active?). to be_truthy
        expect(resident_person.is_resident_role_active?). to be_falsey
      end

      it "should trigger_cdc_to_ivl_transition_notice in queue" do
        ActiveJob::Base.queue_adapter = :test
        ActiveJob::Base.queue_adapter.enqueued_jobs = []
        xhr :post, "transition_family_members_update", resident_params, format: :js
        queued_job = ActiveJob::Base.queue_adapter.enqueued_jobs.find do |job_info|
          job_info[:job] == IvlNoticesNotifierJob
        end
        expect(queued_job[:args]).not_to be_empty
        expect(queued_job[:args].include?(resident_person.id.to_s)).to be_truthy
        expect(queued_job[:args].include?('coverall_to_ivl_transition_notice')).to be_truthy
      end
    end
  end
end

RSpec.describe Insured::FamiliesController, dbclean: :after_each do
  describe "GET purchase" do
    let(:hbx_enrollment) { HbxEnrollment.new }
    let(:family) { FactoryGirl.create(:family, :with_primary_family_member) }
    let(:person) { FactoryGirl.create(:person) }
    let(:user) { FactoryGirl.create(:user, person: person) }
    before :each do
      allow(HbxEnrollment).to receive(:find).and_return hbx_enrollment
      allow(person).to receive(:primary_family).and_return(family)
      allow(hbx_enrollment).to receive(:reset_dates_on_previously_covered_members).and_return(true)
      sign_in(user)
      get :purchase, id: family.id, hbx_enrollment_id: hbx_enrollment.id, terminate: 'terminate'
    end

    it "should get hbx_enrollment" do
      expect(assigns(:enrollment)).to eq hbx_enrollment
    end

    it "should get terminate" do
      expect(assigns(:terminate)).to eq 'terminate'
    end
  end
end
