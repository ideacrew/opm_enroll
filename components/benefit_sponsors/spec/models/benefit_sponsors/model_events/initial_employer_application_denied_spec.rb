require 'rails_helper'

RSpec.describe 'BenefitSponsors::ModelEvents::InitialEmployerApplicationDenied', dbclean: :after_each do

  let(:model_event) { "application_denied" }
  let(:notice_event) { "initial_employer_application_denied" }
  let(:start_on) { TimeKeeper.date_of_record.next_month.beginning_of_month}
  let!(:site)            { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let!(:organization)     { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  let!(:employer_profile)    { organization.employer_profile }
  let!(:benefit_sponsorship)    { employer_profile.add_benefit_sponsorship }
  let!(:model_instance) { FactoryGirl.create(:benefit_sponsors_benefit_application,
    :with_benefit_package,
    :benefit_sponsorship => benefit_sponsorship,
    :aasm_state => 'enrollment_closed',
    :effective_period =>  start_on..(start_on + 1.year) - 1.day
  )}


  describe "ModelEvent" do
    context "when initial employer application is denied" do
      it "should trigger model event" do
        model_instance.class.observer_peers.keys.each do |observer|
          expect(observer).to receive(:notifications_send) do |model_event|
            expect(model_event).to be_an_instance_of(ModelEvents::ModelEvent)
            expect(model_event).to have_attributes(:event_key => :application_denied, :klass_instance => model_instance, :options => {})
          end
        end
        model_instance.deny_enrollment_eligiblity!
      end
    end
  end

  describe "NoticeTrigger" do
    context "when initial application denied" do
      subject { BenefitSponsors::Observers::BenefitApplicationObserver.new }

      let(:model_event) { BenefitSponsors::ModelEvents::ModelEvent.new(:application_denied, model_instance, {}) }

      it "should trigger model event" do
        expect(subject.notifier).to receive(:notify) do |event_name, payload|
          expect(event_name).to eq "acapi.info.events.employer.initial_employer_application_denied"
          expect(payload[:employer_id]).to eq employer_profile.hbx_id.to_s
          expect(payload[:event_object_kind]).to eq 'BenefitSponsors::BenefitApplications::BenefitApplication'
          expect(payload[:event_object_id]).to eq model_instance.id.to_s
        end

        subject.notifications_send(model_instance,model_event)
      end
    end
  end

  describe "NoticeBuilder" do

    let(:data_elements) {
      [
          "employer_profile.notice_date",
          "employer_profile.employer_name",
          "employer_profile.benefit_application.current_py_oe_start_date",
          "employer_profile.benefit_application.current_py_start_date",
          "employer_profile.benefit_application.enrollment_errors",
          "employer_profile.broker_present?"
      ]
    }

    let(:recipient) { "Notifier::MergeDataModels::EmployerProfile" }
    let(:template)  { Notifier::Template.new(data_elements: data_elements) }

    let(:payload)   { {
        "event_object_kind" => "BenefitSponsors::BenefitApplications::BenefitApplication",
        "event_object_id" => model_instance.id
    } }
    let(:merge_model) { subject.construct_notice_object }

    context "when notice event received" do

      subject { Notifier::NoticeKind.new(template: template, recipient: recipient) }

      before do
        allow(subject).to receive(:resource).and_return(employer_profile)
        allow(subject).to receive(:payload).and_return(payload)
        model_instance.deny_enrollment_eligiblity!
      end

      it "should return merge model" do
        expect(merge_model).to be_a(recipient.constantize)
      end
      it "should return notice date" do
        expect(merge_model.notice_date).to eq TimeKeeper.date_of_record.strftime('%m/%d/%Y')
      end
      it "should return employer name" do
        expect(merge_model.employer_name).to eq employer_profile.legal_name
      end
      it "should build return plan year open enrollment start date" do
        expect(merge_model.benefit_application.current_py_oe_start_date).to eq model_instance.open_enrollment_start_on.strftime('%m/%d/%Y')
      end
      it "should return plan year start date" do
        expect(merge_model.benefit_application.current_py_start_date).to eq model_instance.start_on.strftime('%m/%d/%Y')
      end
      it "should return broker status" do
        expect(merge_model.broker_present?).to be_falsey
      end
      it "should return enrollment errors" do
        enrollment_errors = []
      enrollment_policy = BenefitSponsors::BenefitApplications::AcaShopEnrollmentEligibilityPolicy.new
        policy = enrollment_policy.business_policies_for(model_instance, :end_open_enrollment)
        unless policy.is_satisfied?(model_instance)
          policy.fail_results.each do |k, _|
            case k.to_s
            when "minimum_participation_rule"
              enrollment_errors << "At least seventy-five (75) percent of your eligible employees enrolled in your group health coverage or waive due to having other coverage."
            when "non_business_owner_enrollment_count"
              enrollment_errors << "At least one non-owner employee enrolled in health coverage."
            end
          end
      end
        expect(merge_model.benefit_application.enrollment_errors).to eq (enrollment_errors.join(' AND/OR '))
      end
    end
  end
end
