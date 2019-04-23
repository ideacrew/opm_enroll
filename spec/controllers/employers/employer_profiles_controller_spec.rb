require 'rails_helper'

RSpec.describe Employers::EmployerProfilesController, dbclean: :after_each do


  describe "GET index"  do

    let(:user) { double("user") }

    it 'should redirect' do
      sign_in(user)
      get :index
      expect(response).to redirect_to("/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor")
    end

  end

  describe "GET new" do

    let(:user) { double("user") }

    it "should redirect" do
      sign_in(user)
      get :new
      expect(response).to redirect_to("/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor")
    end
  end

  describe "GET show_profile" do

    let(:user) { double("user") }
    let(:employer_profile) { FactoryGirl.create(:employer_profile) }

    it "should redirect" do
      sign_in(user)
      get :show_profile, employer_profile_id: employer_profile
      expect(response).to redirect_to("/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor")
    end
  end

  describe "GET show" do

    let(:user) { double("user") }
    let(:employer_profile) { FactoryGirl.create(:employer_profile) }

    it "should redirect" do
      sign_in(user)
      get :show, id: employer_profile
      expect(response).to redirect_to("/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor")
    end
  end

  describe "GET welcome", dbclean: :after_each do
    let(:user) { double("user") }

    it "should redirect" do
      sign_in(user)
      get :welcome
      expect(response).to redirect_to("/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor")
    end

  end


  describe "GET search", dbclean: :after_each do
    let(:user) { double("user")}
    let(:person) { double("Person")}
    before(:each) do
      allow(user).to receive(:person).and_return(person)
      sign_in user
      get :search
    end

    it "renders the 'search' template" do
      expect(response).to have_http_status(:success)
      expect(response).to render_template("search")
      expect(assigns[:employer_profile]).to be_a(Forms::EmployerCandidate)
    end
  end


  describe "GET export_census_employees", dbclean: :after_each do
    let(:user) { FactoryGirl.create(:user) }
    let(:employer_profile) { FactoryGirl.create(:employer_profile) }

    it "should export cvs" do
      sign_in(user)
      get :export_census_employees, employer_profile_id: employer_profile, format: :csv
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET new Document", dbclean: :after_each do
    let(:user) { FactoryGirl.create(:user) }
    let(:employer_profile) { FactoryGirl.create(:employer_profile) }
    it "should load upload Page" do
      sign_in(user)
      xhr :get, :new_document, id: employer_profile
      expect(response).to have_http_status(:success)
    end
  end


  describe "POST Upload Document", dbclean: :after_each do
    let(:user) { FactoryGirl.create(:user) }
    let(:employer_profile) { FactoryGirl.create(:employer_profile) }
    #let(:params) { { id: employer_profile.id, file:'test/JavaScript.pdf', subject: 'JavaScript.pdf' } }

    let(:subject){"Employee Attestation"}
    let(:file) { double }
    let(:temp_file) { double }
    let(:file_path) { Rails.root+'test/JavaScript.pdf' }

    before(:each) do
      @controller = Employers::EmployerProfilesController.new
      #allow(file).to receive(:original_filename).and_return("some-filename")
      allow(file).to receive(:tempfile).and_return(temp_file)
      allow(temp_file).to receive(:path)
      allow(@controller).to receive(:file_path).and_return(file_path)
      allow(@controller).to receive(:file_name).and_return("sample-filename")
      #allow(@controller).to receive(:file_content_type).and_return("application/pdf")
    end

    context "upload document", dbclean: :after_each do
      it "redirects to document list page" do
        sign_in user
        post :upload_document, {:id => employer_profile.id, :file => file, :subject=> subject}
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "Delete Document", dbclean: :after_each do
    let(:user) { FactoryGirl.create(:user) }
    let(:employer_profile) { FactoryGirl.create(:employer_profile) }

    it "should delete documents" do
      sign_in(user)
      xhr :get, :delete_documents, id: employer_profile.id, ids:[1]
      expect(response).to have_http_status(:success)
    end
  end
end
