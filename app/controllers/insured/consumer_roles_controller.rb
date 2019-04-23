class Insured::ConsumerRolesController < ApplicationController
  include ApplicationHelper
  include VlpDoc
  include ErrorBubble
  include NavigationHelper

  before_action :check_consumer_role, only: [:search, :match]
  before_action :find_consumer_role, only: [:edit, :update]
  before_action :individual_market_is_enabled?
  #before_action :authorize_for, except: [:edit, :update]

  def ssn_taken
  end

  def privacy
    set_current_person(required: false)
    @val = params[:aqhp] || params[:uqhp]
    @key = params.key(@val)
    @search_path = {@key => @val}
    if @person.try(:resident_role?)
      bookmark_url = @person.resident_role.bookmark_url.to_s.present? ? @person.resident_role.bookmark_url.to_s : nil
      redirect_to bookmark_url || family_account_path
    elsif @person.try(:consumer_role?)
      bookmark_url = @person.consumer_role.bookmark_url.to_s.present? ? @person.consumer_role.bookmark_url.to_s + "?#{@key.to_s}=#{@val.to_s}" : nil
      redirect_to bookmark_url || family_account_path
    end
  end


  def search
    @no_previous_button = true
    @no_save_button = true
    if params[:aqhp].present?
      session[:individual_assistance_path] = true
    else
      session.delete(:individual_assistance_path)
    end

    if params.permit(:build_consumer_role)[:build_consumer_role].present? && session[:person_id]
      person = Person.find(session[:person_id])

      @person_params = person.attributes.extract!("first_name", "middle_name", "last_name", "gender")
      @person_params[:ssn] = Person.decrypt_ssn(person.encrypted_ssn)
      @person_params[:dob] = person.dob.strftime("%Y-%m-%d")

      @person = Forms::ConsumerCandidate.new(@person_params)
    else
      @person = Forms::ConsumerCandidate.new
    end

    respond_to do |format|
      format.html
    end
  end

  def match
    @no_save_button = true
    @person_params = params.require(:person).merge({user_id: current_user.id})
    @consumer_candidate = Forms::ConsumerCandidate.new(@person_params)
    @person = @consumer_candidate
    @use_person = true #only used to manupulate form data
    respond_to do |format|
      if @consumer_candidate.valid?
        idp_search_result = nil
        if current_user.idp_verified?
          idp_search_result = :not_found
        else
          idp_search_result = IdpAccountManager.check_existing_account(@consumer_candidate)
        end
        case idp_search_result
        when :service_unavailable
          format.html { render 'shared/account_lookup_service_unavailable' }
        when :too_many_matches
          format.html { redirect_to SamlInformation.account_conflict_url }
        when :existing_account
          format.html { redirect_to SamlInformation.account_recovery_url }
        else
          unless params[:persisted] == "true"
            @employee_candidate = Forms::EmployeeCandidate.new(@person_params)

            if @employee_candidate.valid?
              found_census_employees = @employee_candidate.match_census_employees
              @employment_relationships = Factories::EmploymentRelationshipFactory.build(@employee_candidate, found_census_employees)
              if @employment_relationships.present?
                format.html { render 'insured/employee_roles/match' }
              end
            end
          end
          @resident_candidate = Forms::ResidentCandidate.new(@person_params)
          if @resident_candidate.valid?
            found_person = @resident_candidate.match_person
            if found_person.present? && found_person.resident_role.present?
              begin
                @resident_role = Factories::EnrollmentFactory.construct_resident_role(params.permit!, actual_user)
                if @resident_role.present?
                  @person = @resident_role.person
                  session[:person_id] = @person.id
                else
                # not logging error because error was logged in construct_consumer_role
                  render file: 'public/500.html', status: 500
                  return
                end
              rescue Exception => e
                flash[:error] = set_error_message(e.message)
                redirect_to search_exchanges_residents_path
                return
              end
              create_sso_account(current_user, @person, 15, "resident") do
                respond_to do |format|
                  format.html {
                    redirect_to family_account_path
                  }
                end
              end
            end
            return
          end

          found_person = @consumer_candidate.match_person
          if found_person.present?
            format.html { render 'match' }
          else
            format.html { render 'no_match' }
          end
        end
      elsif @consumer_candidate.errors[:ssn_dob_taken].present?
        format.html { render 'search' }
      elsif @consumer_candidate.errors[:ssn_taken].present?
        text = "The SSN entered is associated with an existing user. "
        text += "Please #{view_context.link_to('Sign In', SamlInformation.iam_login_url)} with your user name and password "
        text += "or #{view_context.link_to('Click here', SamlInformation.account_recovery_url)} if you've forgotten your password."
        flash[:alert] = text
        format.html {redirect_to ssn_taken_insured_consumer_role_index_path}
      else
        format.html { render 'search' }
      end
    end
  end

  def build
    set_current_person(required: false)
    build_person_params
    render 'match'
  end

  def create
    begin
      @consumer_role = Factories::EnrollmentFactory.construct_consumer_role(params.permit!, actual_user)
      if @consumer_role.present?
        @person = @consumer_role.person
      else
      # not logging error because error was logged in construct_consumer_role
        render file: 'public/500.html', status: 500
        return
      end
    rescue Exception => e
      flash[:error] = set_error_message(e.message)
      redirect_to search_insured_consumer_role_index_path
      return
    end
    @person.primary_family.create_dep_consumer_role if @person
    is_assisted = session["individual_assistance_path"]
    role_for_user = (is_assisted) ? "assisted_individual" : "individual"
    create_sso_account(current_user, @person, 15, role_for_user) do
      respond_to do |format|
        format.html {
          if is_assisted
            @person.primary_family.update_attribute(:e_case_id, "curam_landing_for#{@person.id}") if @person.primary_family
            redirect_to navigate_to_assistance_saml_index_path
          else
            redirect_to :action => "edit", :id => @consumer_role.id
          end
        }
      end
    end
  end

  def immigration_document_options
    if params[:target_type] == "Person"
      @target = Person.find(params[:target_id])
      vlp_docs = @target.consumer_role.vlp_documents
    elsif params[:target_type] == "Forms::FamilyMember"
      if params[:target_id].present?
        @target = Forms::FamilyMember.find(params[:target_id])
        vlp_docs = @target.family_member.person.consumer_role.vlp_documents
      else
        @target = Forms::FamilyMember.new
      end
    end
    @vlp_doc_target = params[:vlp_doc_target]
    vlp_doc_subject = params[:vlp_doc_subject]
    @country = vlp_docs.detect{|doc| doc.subject == vlp_doc_subject }.try(:country_of_citizenship) if vlp_docs
  end

  def edit
    authorize @consumer_role, :edit?
    set_consumer_bookmark_url
    @consumer_role.build_nested_models_for_person
    @vlp_doc_subject = get_vlp_doc_subject_by_consumer_role(@consumer_role)
    respond_to do |format|
      format.js
      format.html
    end
  end

  def update
    #authorize @consumer_role, :update?
    save_and_exit =  params['exit_after_method'] == 'true'

    if update_vlp_documents(@consumer_role, 'person') && @consumer_role.update_by_person(params.require(:person).permit(*person_parameters_list))
      @consumer_role.update_attribute(:is_applying_coverage, params[:person][:is_applying_coverage])
      @person.primary_family.update_attributes(application_type: params["person"]["family"]["application_type"]) if current_user.has_hbx_staff_role?
      if save_and_exit
        respond_to do |format|
          format.html {redirect_to destroy_user_session_path}
        end
      else
        check_redirection_path
      end
    else
      if save_and_exit
        respond_to do |format|
          format.html {redirect_to destroy_user_session_path}
        end
      else
        @consumer_role.build_nested_models_for_person
        @vlp_doc_subject = get_vlp_doc_subject_by_consumer_role(@consumer_role)
        bubble_address_errors_by_person(@consumer_role.person)
        respond_to do |format|
          format.html { render "edit" }
        end
      end
    end
  end

  def ridp_agreement
    set_current_person
    consumer = @person.consumer_role
    if @person.completed_identity_verification? || consumer.identity_verified?
      redirect_to consumer.admin_bookmark_url.present? ? consumer.admin_bookmark_url : help_paying_coverage_financial_assistance_applications_path
    else
      set_consumer_bookmark_url
    end
  end

  def upload_ridp_document
    set_consumer_bookmark_url
    set_current_person
    @person.consumer_role.move_identity_documents_to_outstanding
  end

  def update_application_type
    set_current_person
    application_type = params[:consumer_role][:family][:application_type]
    @person.primary_family.update_attributes(application_type: application_type)
    if @person.primary_family.has_curam_or_mobile_application_type?
      @person.consumer_role.move_identity_documents_to_verified(@person.primary_family.application_type)
      redirect_to help_paying_coverage_financial_assistance_applications_path
    else
      redirect_to :back
    end
  end

  private

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    if current_user.has_consumer_role?
      respond_to do |format|
        format.html { redirect_to edit_insured_consumer_role_path(current_user.person.consumer_role.id) }
      end
    else
      flash[:error] = "We're sorry. Due to circumstances out of your control an error has occured."
      respond_to do |format|
        format.json { redirect_to destroy_user_session_path }
        format.html { redirect_to destroy_user_session_path }
        format.js   { redirect_to destroy_user_session_path }
      end
    end
  end

  def person_parameters_list
    [
      { :addresses_attributes => [:kind, :address_1, :address_2, :city, :state, :zip, :id, :_destroy] },
      { :phones_attributes => [:kind, :full_phone_number, :id, :_destroy] },
      { :emails_attributes => [:kind, :address, :id, :_destroy] },
      { :consumer_role_attributes => [:contact_method, :language_preference]},
      :first_name,
      :last_name,
      :middle_name,
      :name_pfx,
      :name_sfx,
      :dob,
      :ssn,
      :no_ssn,
      :gender,
      :language_code,
      :is_incarcerated,
      :is_disabled,
      :race,
      :is_consumer_role,
      :is_resident_role,
      {:ethnicity => []},
      :us_citizen,
      :naturalized_citizen,
      :eligible_immigration_status,
      :indian_tribe_member,
      :tribal_id,
      :no_dc_address,
      :is_homeless,
      :is_temporarily_out_of_state,
      :is_applying_coverage
    ]
  end

  def find_consumer_role
    @consumer_role = ConsumerRole.find(params.require(:id))
    @person = @consumer_role.person
  end


  def check_consumer_role
    set_current_person(required: false)
    # need this check for cover all
    if @person.try(:is_resident_role_active?)
      redirect_to @person.resident_role.bookmark_url || family_account_path
    elsif @person.try(:is_consumer_role_active?)
      redirect_to @person.consumer_role.bookmark_url || family_account_path
    else
      current_user.last_portal_visited = search_insured_consumer_role_index_path
      current_user.save!
      # render 'privacy'
    end
  end

  def create_initial_market_transition
    transition = IndividualMarketTransition.new
    transition.role_type = "consumer"
    transition.submitted_at = TimeKeeper.datetime_of_record
    transition.reason_code = "generating_consumer_role"
    transition.effective_starting_on = TimeKeeper.datetime_of_record
    transition.user_id = current_user.id
    Person.find(session[:person_id]).individual_market_transitions << transition
  end

  def set_error_message(message)
    if message.include? "year too big to marshal"
      return "Date of birth cannot be more than 110 years ago"
    else
      return message
    end
  end

  def load_support_texts
    @support_texts = YAML.load_file("app/views/shared/support_text_household.yml")
  end

  def check_redirection_path
    if current_user.has_hbx_staff_role? && (@person.primary_family.application_type == "Paper" || @person.primary_family.application_type == "In Person")
      redirect_to upload_ridp_document_insured_consumer_role_index_path
    elsif is_new_paper_application?(current_user, session[:original_application_type]) || @person.primary_family.has_curam_or_mobile_application_type?
      @person.consumer_role.move_identity_documents_to_verified(@person.primary_family.application_type)
      redirect_to @consumer_role.admin_bookmark_url.present? ? @consumer_role.admin_bookmark_url : help_paying_coverage_financial_assistance_applications_path
    else
      redirect_to ridp_agreement_insured_consumer_role_index_path
    end
  end

  def build_person_params
   @person_params = {:ssn =>  Person.decrypt_ssn(@person.encrypted_ssn)}

    %w(first_name middle_name last_name gender).each do |field|
      @person_params[field] = @person.attributes[field]
    end

    @person_params[:dob] = @person.dob.strftime("%Y-%m-%d")
    @person_params.merge!({user_id: current_user.id})
  end
end
