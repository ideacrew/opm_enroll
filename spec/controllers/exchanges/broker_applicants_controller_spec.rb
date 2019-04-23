require 'rails_helper'

RSpec.describe Exchanges::BrokerApplicantsController do

  describe ".index" do
    let(:user) { instance_double("User", :has_hbx_staff_role? => true) }

    before :each do
      sign_in(user)
      xhr :get, :index, format: :js
    end

    it "should render index" do
      expect(assigns(:broker_applicants))
      expect(response).to have_http_status(:success)
      expect(response).to render_template("exchanges/broker_applicants/index")
    end

    context 'when hbx staff role missing' do
      let(:user) { instance_double("User", :has_hbx_staff_role? => false) }

      it 'should redirect when hbx staff role missing' do
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to('/exchanges/hbx_profiles')
      end
    end
  end

  describe ".edit" do
    let(:user) { instance_double("User", :has_hbx_staff_role? => true) }
    let(:broker_role) {FactoryGirl.create(:broker_role)}

    before :each do
      sign_in(user)
      xhr :get, :edit, id: broker_role.person.id, format: :js
    end

    it "should render edit" do
      expect(assigns(:broker_applicant))
      expect(response).to have_http_status(:success)
      expect(response).to render_template("exchanges/broker_applicants/edit")
    end
  end

  describe ".update" do
    let(:user) { instance_double("User", :has_hbx_staff_role? => true) }
    let(:broker_role) {FactoryGirl.create(:broker_role)}

    before :all do
      @broker_agency_profile = FactoryGirl.create(:broker_agency).broker_agency_profile
    end

    before :each do
      @broker_agency_profile.update_attributes({ primary_broker_role: broker_role })
      sign_in(user)
    end

    context 'when application denied' do
      before :each do
        put :update, id: broker_role.person.id, deny: true, format: :js
        broker_role.reload
      end

      it "should change applicant status to denied" do
        expect(assigns(:broker_applicant))
        expect(broker_role.aasm_state).to eq 'denied'
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to('/exchanges/hbx_profiles')
      end
    end

    context 'when application approved and applicant is not primary broker' do

      before :each do
        FactoryGirl.create(:hbx_profile)
        put :update, id: broker_role.person.id, approve: true, person: { broker_role_attributes: { training: true , carrier_appointments: {}} } , format: :js
        broker_role.reload
      end

      it "should approve and change status to broker agency pending" do
        allow(broker_role).to receive(:broker_agency_profile).and_return(@broker_agency_profile)

        expect(assigns(:broker_applicant))
        expect(broker_role.aasm_state).to eq 'broker_agency_pending'
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to('/exchanges/hbx_profiles')
      end
    end

    context 'when applicant is a primary broker' do
      let(:broker_agency_profile) { FactoryGirl.create(:broker_agency_profile, primary_broker_role_id: broker_role.id) }

      context 'when application is approved' do
        before :each do
          broker_role.update_attributes({ broker_agency_profile_id: @broker_agency_profile.id })
          put :update, id: broker_role.person.id, approve: true, person: { broker_role_attributes: { training: true , carrier_appointments: {}} } , format: :js
          broker_role.reload
        end

        it "should change applicant status to active" do
          expect(assigns(:broker_applicant))
          expect(broker_role.aasm_state).to eq 'active'
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to('/exchanges/hbx_profiles')
        end

        it "should have training as true in broker role attributes" do
          expect(broker_role.training).to eq true
        end
      end

      context 'when application is updated' do
        before :each do
          broker_role.update_attributes({ broker_agency_profile_id: @broker_agency_profile.id })
          broker_role.approve!
          put :update, id: broker_role.person.id, update: true, person: { broker_role_attributes: { training: true , carrier_appointments: {"Aetna Health Inc"=>"true", "United Health Care Insurance"=>"true"}} } , format: :js
          broker_role.reload
        end

        it "should change applicant status to active" do
          expect(assigns(:broker_applicant))
          expect(broker_role.aasm_state).to eq 'active'
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to('/exchanges/hbx_profiles')
          #only really testing that the params go through.
          if aca_state_abbreviation == "DC"
            expect(broker_role.carrier_appointments).to eq({"Aetna Health Inc"=>"true", "Aetna Life Insurance Company"=>nil, "Carefirst Bluechoice Inc"=>nil, "Group Hospitalization and Medical Services Inc"=>nil, "Kaiser Foundation"=>nil, "Optimum Choice"=>nil, "United Health Care Insurance"=>"true", "United Health Care Mid Atlantic"=>nil})
          else
            expect(broker_role.carrier_appointments).to eq({"Aetna Health Inc"=>"true", "Altus" => nil, "Blue Cross Blue Shield MA" => nil, "Boston Medical Center Health Plan" => nil, "Delta" => nil, "FCHP" => nil, "Guardian" => nil, "Harvard Pilgrim Health Care" => nil, "Health New England" => nil, "Minuteman Health" => nil, "Neighborhood Health Plan" => nil, "Tufts Health Plan Direct" => nil, "Tufts Health Plan Premier" => nil, "United Health Care Insurance" => "true"})
          end
        end

        it "should have training as true in broker role attributes" do
          expect(broker_role.training).to eq true
        end
      end

      context 'when broker carrier appointments enabled and application is pending' do
        context 'when application is pending' do
          before :each do
            Settings.aca.broker_carrier_appointments_enabled = true
            broker_role.update_attributes({ broker_agency_profile_id: @broker_agency_profile.id })
            put :update, id: broker_role.person.id, pending: true, person:  { broker_role_attributes: { training: true , carrier_appointments: {}} } , format: :js
            broker_role.reload
          end

          it "all broker carrier appointments should be true" do
            expect(broker_role.carrier_appointments).to eq("Altus"=>"true",
                                                            "Blue Cross Blue Shield MA"=>"true",
                                                            "Boston Medical Center Health Plan"=>"true",
                                                            "Delta"=>"true",
                                                            "FCHP"=>"true",
                                                            "Guardian"=>"true",
                                                            "Health New England"=>"true",
                                                            "Harvard Pilgrim Health Care"=>"true",
                                                            "Minuteman Health"=>"true",
                                                            "Neighborhood Health Plan"=>"true",
                                                            "Tufts Health Plan Direct"=>"true",
                                                            "Tufts Health Plan Premier"=>"true")
          end

          it "should change applicant status to broker_agency_pending" do
            expect(assigns(:broker_applicant))
            expect(broker_role.aasm_state).to eq 'broker_agency_pending'
            expect(response).to have_http_status(:redirect)
            expect(response).to redirect_to('/exchanges/hbx_profiles')
          end

          it "should have training as true in broker role attributes" do
            expect(broker_role.training).to eq true
          end
        end
      end

      context 'when broker carrier appointments disabled and application is pending' do
        context 'when application is pending' do
          before :each do
            Settings.aca.broker_carrier_appointments_enabled = false
            broker_role.update_attributes({ broker_agency_profile_id: @broker_agency_profile.id })
            put :update, id: broker_role.person.id, pending: true, person:  { broker_role_attributes: { training: true , carrier_appointments: {"Altus"=>"true",
                                      "Blue Cross Blue Shield MA"=>"true",
                                      "Boston Medical Center Health Plan"=>"true",
                                      "Delta"=>nil,
                                      "FCHP"=>nil,
                                      "Guardian"=>"true",
                                      "Health New England"=>nil,
                                      "Harvard Pilgrim Health Care"=>nil,
                                      "Minuteman Health"=>nil,
                                      "Neighborhood Health Plan"=>nil,
                                      "Tufts Health Plan Direct"=>nil,
                                      "Tufts Health Plan Premier"=>nil}  } } , format: :js
            broker_role.reload
          end

          it "broker carrier appointments should be user selected" do
            expect(broker_role.carrier_appointments).to eq("Altus"=>"true",
                                                            "Blue Cross Blue Shield MA"=>"true",
                                                            "Boston Medical Center Health Plan"=>"true",
                                                            "Delta"=>nil,
                                                            "FCHP"=>nil,
                                                            "Guardian"=>"true",
                                                            "Health New England"=>nil,
                                                            "Harvard Pilgrim Health Care"=>nil,
                                                            "Minuteman Health"=>nil,
                                                            "Neighborhood Health Plan"=>nil,
                                                            "Tufts Health Plan Direct"=>nil,
                                                            "Tufts Health Plan Premier"=>nil)
          end

          it "should change applicant status to broker_agency_pending" do
            expect(assigns(:broker_applicant))
            expect(broker_role.aasm_state).to eq 'broker_agency_pending'
            expect(response).to have_http_status(:redirect)
            expect(response).to redirect_to('/exchanges/hbx_profiles')
          end

          it "should have training as true in broker role attributes" do
            expect(broker_role.training).to eq true
          end
        end
      end

      context 'when application is decertified' do
        before :each do
          broker_role.update_attributes({ broker_agency_profile_id: @broker_agency_profile.id })
          broker_role.approve!
          put :update, id: broker_role.person.id, decertify: true, format: :js
          broker_role.reload
        end

        it "should change applicant status to decertified" do
          expect(assigns(:broker_applicant))
          expect(broker_role.aasm_state).to eq 'decertified'
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to('/exchanges/hbx_profiles')
        end
      end

      context 'when application is re-certified' do
        before :each do
          broker_role.update_attributes({ broker_agency_profile_id: @broker_agency_profile.id })
          broker_role.approve!
          broker_role.decertify!
          put :update, id: broker_role.person.id, recertify: true, format: :js
          broker_role.reload
        end

        it "should change applicant status to active" do
          expect(assigns(:broker_applicant))
          expect(broker_role.aasm_state).to eq 'active'
          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to('/exchanges/hbx_profiles')
        end
      end
    end
  end
end
