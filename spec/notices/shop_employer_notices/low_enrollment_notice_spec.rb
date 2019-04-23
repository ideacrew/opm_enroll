require 'rails_helper'

RSpec.describe ShopEmployerNotices::LowEnrollmentNotice, dbclean: :after_each do
  let!(:employer_profile){ create :employer_profile}
  let!(:person){ create :person}
  let(:application_event){ double("ApplicationEventKind",{
                            :name =>'Low Enrollment Notice',
                            :notice_template => 'notices/shop_employer_notices/low_enrollment_notice_for_employer',
                            :notice_builder => 'ShopEmployerNotices::LowEnrollmentNotice',
                            :event_name => 'low_enrollment_notice_for_employer',
                            :mpi_indicator => 'MPI_DAG015',
                            :title => "Notice of Low Enrollment - Action Needed"})
                          }
    let(:valid_params) {{
        :subject => application_event.title,
        :mpi_indicator => application_event.mpi_indicator,
        :event_name => application_event.event_name,
        :template => application_event.notice_template
    }}

  before do
    allow(employer_profile).to receive_message_chain("staff_roles.first").and_return(person)
    @employer_notice = ShopEmployerNotices::LowEnrollmentNotice.new(employer_profile, valid_params)
  end

  describe "New" do
    context "valid params" do
      it "should initialze" do
        expect{ShopEmployerNotices::LowEnrollmentNotice.new(employer_profile, valid_params)}.not_to raise_error
      end
    end

    context "invalid params" do
      [:mpi_indicator,:subject,:template].each do  |key|
        it "should NOT initialze with out #{key}" do
          valid_params.delete(key)
          expect{ShopEmployerNotices::LowEnrollmentNotice.new(employer_profile, valid_params)}.to raise_error(RuntimeError,"Required params #{key} not present")
        end
      end
    end
  end

  describe "Build" do
    it "should build notice with all necessory info" do
      @employer_notice.build
      expect(@employer_notice.notice.primary_fullname).to eq person.full_name.titleize
      expect(@employer_notice.notice.employer_name).to eq employer_profile.organization.legal_name
      expect(@employer_notice.notice.primary_identifier).to eq employer_profile.hbx_id
    end
  end

  describe "append data" do
    context "initial employer" do
      let(:start_on) { TimeKeeper.date_of_record.beginning_of_month + 1.month - 1.year}
      let!(:plan_year) { FactoryGirl.create(:plan_year, employer_profile: employer_profile, start_on: start_on, :aasm_state => 'enrolling' ) }
      let!(:active_benefit_group) { FactoryGirl.create(:benefit_group, plan_year: plan_year, title: "Benefits #{plan_year.start_on.year}") }

      before do
        allow(plan_year).to receive(:eligible_to_enroll_count).and_return(10)
        allow(plan_year).to receive(:total_enrolled_count).and_return(4)
        @employer_notice.append_data
      end

      it "should return plan year open_enrollment_end_on" do
        expect(@employer_notice.notice.plan_year.open_enrollment_end_on).to eq plan_year.open_enrollment_end_on
      end

      it "should return plan year eligible_to_enroll_count" do
        expect(@employer_notice.notice.plan_year.eligible_to_enroll_count).to eq plan_year.eligible_to_enroll_count
      end

      it "should return plan year total_enrolled_count" do
        expect(@employer_notice.notice.plan_year.total_enrolled_count).to eq plan_year.total_enrolled_count
      end

      it "should return plan year due_date" do
        due_date = PlanYear.calculate_open_enrollment_date(plan_year.start_on)[:binder_payment_due_date]
        expect(@employer_notice.notice.plan_year.binder_payment_due_date).to eq due_date
      end
    end

    context "renewing employer" do
      let(:start_on) { TimeKeeper.date_of_record.beginning_of_month + 1.month - 1.year}
      let!(:plan_year) { FactoryGirl.create(:plan_year, employer_profile: employer_profile, start_on: start_on, :aasm_state => 'active' ) }
      let!(:active_benefit_group) { FactoryGirl.create(:benefit_group, plan_year: plan_year, title: "Benefits #{plan_year.start_on.year}") }
      let!(:renewal_plan_year) { FactoryGirl.create(:plan_year, employer_profile: employer_profile, start_on: start_on + 1.year, :aasm_state => 'renewing_enrolling' ) }
      let!(:renewal_benefit_group) { FactoryGirl.create(:benefit_group, plan_year: renewal_plan_year, title: "Benefits #{renewal_plan_year.start_on.year}") }

      before do
        allow(renewal_plan_year).to receive(:eligible_to_enroll_count).and_return(10)
        allow(renewal_plan_year).to receive(:total_enrolled_count).and_return(4)
        @employer_notice.append_data
      end

      it "should return renewing plan year open_enrollment_end_on" do
        expect(@employer_notice.notice.plan_year.open_enrollment_end_on).to eq renewal_plan_year.open_enrollment_end_on
      end

      it "should return renewing plan year eligible_to_enroll_count" do
        expect(@employer_notice.notice.plan_year.eligible_to_enroll_count).to eq renewal_plan_year.eligible_to_enroll_count
      end

      it "should return renewing plan year total_enrolled_count" do
        expect(@employer_notice.notice.plan_year.total_enrolled_count).to eq renewal_plan_year.total_enrolled_count
      end

      it "should return renewing plan year due_date" do
        due_date = PlanYear.calculate_open_enrollment_date(renewal_plan_year.start_on)[:binder_payment_due_date]
        expect(@employer_notice.notice.plan_year.binder_payment_due_date).to eq due_date
      end

      describe "for generating pdf" do
        it "should generate pdf" do
          @employer_notice.build
          @employer_notice.append_data
          file = @employer_notice.generate_pdf_notice
          expect(File.exist?(file.path)).to be true
        end
      end
    end
  end

  describe "should render template" do
    it "render low_enrollment_notice_for_employer" do
      expect(@employer_notice.template).to eq "notices/shop_employer_notices/low_enrollment_notice_for_employer"
    end
  end
end
