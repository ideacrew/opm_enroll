require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "upload_notice_to_employer_account")

describe UploadNoticeToEmployerAccount, dbclean: :after_each do

  let(:given_task_name) { "upload_notice_to_employer_account" }
  subject { UploadNoticeToEmployerAccount.new(given_task_name, double(:current_scope => nil)) }
  let!(:site) { FactoryGirl.build(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let!(:organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  let(:bucket_name) { 'notices' }
  let(:doc_id) { "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket_name}{#sample-key" }
  let(:employer_profile) { organization.employer_profile}

  before(:each) do
    FileUtils.mkdir "test_notices" unless File.directory?("test_notices")
    File.new("test_notices/notice1.pdf", "w") unless File.file?("test_notices/notice1.pdf")
    @file_path = "test_notices/notice1.pdf"
    allow(ENV).to receive(:[]).with('fein').and_return(organization.fein)
    allow(ENV).to receive(:[]).with('notice_name').and_return('Special Enrollment Denial Notice')
  end

  context "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  context "upload notice" do
    it "should save notice as documents under employer profile" do
      allow(ENV).to receive(:[]).with('file_path').and_return(@file_path)
      allow(Aws::S3Storage).to receive(:save).with(@file_path, bucket_name).and_return(doc_id)
      expect(employer_profile.documents.size).to eq 0
      subject.migrate
      employer_profile.reload
      expect(employer_profile.documents.size).to eq 1
    end
  end

  context "create_secure_inbox_message" do
    it "should send secure inbox message to employer account" do
      allow(ENV).to receive(:[]).with('file_path').and_return(@file_path)
      allow(Aws::S3Storage).to receive(:save).with(@file_path, bucket_name).and_return(doc_id)
      expect(employer_profile.inbox.messages.size).to eq 0
      subject.migrate
      employer_profile.reload
      expect(employer_profile.inbox.messages.size).to eq 1
    end
  end

  context "for a case when doc_uri is nil" do
    it "should not send secure inbox message to employer account when the pdf is not uploaded to S3 instead should raise error" do
      allow(ENV).to receive(:[]).with('file_path').and_return(@file_path)
      allow(Aws::S3Storage).to receive(:save).with(@file_path, bucket_name).and_return(nil)
      expect(employer_profile.inbox.messages.size).to eq 0
      expect{subject.migrate}.to raise_error(RuntimeError, /Unable to generate the doc_uri for notice: SpecialEnrollmentDenialNotice to #{employer_profile.legal_name}'s account/)
      expect(employer_profile.inbox.messages.size).to eq 0
    end
  end

  context "for a case when file doesn't exist" do
    it "should not send secure inbox message to employer account when the pdf doesn't exist" do
      allow(ENV).to receive(:[]).with('file_path').and_return("test_notices/notice1843.pdf")
      allow(Aws::S3Storage).to receive(:save).with("test_notices/notice1843.pdf", bucket_name).and_return(doc_id)
      expect(employer_profile.inbox.messages.size).to eq 0
      expect{subject.migrate}.to raise_error(RuntimeError, /Unable to find the pdf notice as per the given file name: test_notices\/notice1843.pdf/)
      expect(employer_profile.inbox.messages.size).to eq 0
    end
  end

  after(:all) do
    FileUtils.rm_rf(Dir["#{Rails.root}/test_notices"])
  end
end
