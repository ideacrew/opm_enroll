class EmployerProfile
  include Mongoid::Document
  include SetCurrentUser
  include Mongoid::Timestamps
  include AASM
  include Acapi::Notifiers
  extend Acapi::Notifiers
  include StateTransitionPublisher

  embedded_in :organization
  attr_accessor :broker_role_id

  BINDER_PREMIUM_PAID_EVENT_NAME = "acapi.info.events.employer.binder_premium_paid"
  EMPLOYER_PROFILE_UPDATED_EVENT_NAME = "acapi.info.events.employer.updated"
  INITIAL_APPLICATION_ELIGIBLE_EVENT_TAG="benefit_coverage_initial_application_eligible"
  INITIAL_EMPLOYER_TRANSMIT_EVENT="acapi.info.events.employer.benefit_coverage_initial_application_eligible"
  RENEWAL_APPLICATION_ELIGIBLE_EVENT_TAG="benefit_coverage_renewal_application_eligible"
  RENEWAL_EMPLOYER_TRANSMIT_EVENT="acapi.info.events.employer.benefit_coverage_renewal_application_eligible"
  RENEWAL_APPLICATION_CARRIER_DROP_EVENT_TAG="benefit_coverage_renewal_carrier_dropped"
  RENEWAL_EMPLOYER_CARRIER_DROP_EVENT="acapi.info.events.employer.benefit_coverage_renewal_carrier_dropped"

  ACTIVE_STATES   = ["applicant", "registered", "eligible", "binder_paid", "enrolled"]
  INACTIVE_STATES = ["suspended", "ineligible"]

  PROFILE_SOURCE_KINDS  = ["self_serve", "conversion"]

  INVOICE_VIEW_INITIAL  = %w(published enrolling enrolled active suspended)
  INVOICE_VIEW_RENEWING = %w(renewing_published renewing_enrolling renewing_enrolled renewing_draft)

  ENROLLED_STATE = %w(enrolled suspended)

  field :entity_kind, type: String
  field :sic_code, type: String

  field :no_ssn, type: Boolean, default: false
  field :enable_ssn_date, type: DateTime
  field :disable_ssn_date, type: DateTime

#  field :converted_from_carrier_at, type: DateTime, default: nil
#  field :conversion_carrier_id, type: BSON::ObjectId, default: nil

  # Workflow attributes
  field :aasm_state, type: String, default: "applicant"


  field :profile_source, type: String, default: "self_serve"
  field :contact_method, type: String, default: "Only Electronic communications"
  field :registered_on, type: Date, default: ->{ TimeKeeper.date_of_record }
  field :xml_transmitted_timestamp, type: DateTime

  delegate :hbx_id, to: :organization, allow_nil: true
  delegate :legal_name, :legal_name=, to: :organization, allow_nil: true
  delegate :dba, :dba=, to: :organization, allow_nil: true
  delegate :fein, :fein=, to: :organization, allow_nil: true
  delegate :is_active, :is_active=, to: :organization, allow_nil: false
  delegate :updated_by, :updated_by=, to: :organization, allow_nil: false

  # TODO: make these relative to enrolling plan year
  # delegate :eligible_to_enroll_count, to: :enrolling_plan_year, allow_nil: true
  # delegate :non_business_owner_enrollment_count, to: :enrolling_plan_year, allow_nil: true
  # delegate :total_enrolled_count, to: :enrolling_plan_year, allow_nil: true
  # delegate :enrollment_ratio, to: :enrolling_plan_year, allow_nil: true
  # delegate :is_enrollment_valid?, to: :enrolling_plan_year, allow_nil: true
  # delegate :enrollment_errors, to: :enrolling_plan_year, allow_nil: true

  embeds_one  :inbox, as: :recipient, cascade_callbacks: true
  embeds_one  :employer_profile_account
  embeds_many :plan_years, cascade_callbacks: true, validate: true
  embeds_many :broker_agency_accounts, cascade_callbacks: true, validate: true
  embeds_many :general_agency_accounts, cascade_callbacks: true, validate: true

  embeds_many :workflow_state_transitions, as: :transitional
  embeds_many :documents, as: :documentable

  accepts_nested_attributes_for :plan_years, :inbox, :employer_profile_account, :broker_agency_accounts, :general_agency_accounts

  validates_presence_of :entity_kind

  validates :profile_source,
    inclusion: { in: EmployerProfile::PROFILE_SOURCE_KINDS },
    allow_blank: false

  validates :entity_kind,
    inclusion: { in: Organization::ENTITY_KINDS, message: "%{value} is not a valid business entity kind" },
    allow_blank: false

  after_initialize :build_nested_models
  after_save :save_associated_nested_models

  scope :active,      ->{ any_in(aasm_state: ACTIVE_STATES) }
  scope :inactive,    ->{ any_in(aasm_state: INACTIVE_STATES) }

  scope :all_renewing, ->{ Organization.all_employers_renewing }
  scope :all_with_next_month_effective_date,  ->{ Organization.all_employers_by_plan_year_start_on(TimeKeeper.date_of_record.end_of_month + 1.day) }

  alias_method :is_active?, :is_active

  # def self.all_with_next_month_effective_date
    # Organization.all_employers_by_plan_year_start_on(TimeKeeper.date_of_record.end_of_month + 1.day)
  # end

  def parent
    raise "undefined parent Organization" unless organization?
    organization
  end


  def census_employees
    employer_profile = self
      Person.where("employee_roles.employer_profile_id" => employer_profile.id).reduce([]) do |list, person|
      list << person.employee_roles.detect { |ee| ee.employer_profile_id == employer_profile.id }
    end
  end

  def covered_employee_roles
    covered_ee_ids = CensusEmployee.by_employer_profile_id(self.id).covered.only(:employee_role_id)
    EmployeeRole.ids_in(covered_ee_ids)
  end

  def owners #business owners
    staff_roles.select{|p| p.try(:employee_roles).try(:any?){|ee| ee.census_employee.is_business_owner? }}
  end

  def staff_roles #managing profile staff
    Person.staff_for_employer(self)
  end

  def match_employer(current_user)
    staff_roles.detect {|staff| staff.id == current_user.person_id}
  end

  def today=(new_date)
    raise ArgumentError.new("expected Date") unless new_date.is_a?(Date)
    @today = new_date
  end

  def today
    return @today if defined? @today
    @today = TimeKeeper.date_of_record
  end

  # for broker agency
  def hire_broker_agency(new_broker_agency, start_on = today)
    start_on = start_on.to_date.beginning_of_day
    if active_broker_agency_account.present?
      terminate_on = (start_on - 1.day).end_of_day
      fire_broker_agency(terminate_on)
      fire_general_agency!(terminate_on)
    end
    broker_agency_accounts.build(broker_agency_profile: new_broker_agency, writing_agent_id: broker_role_id, start_on: start_on)
    @broker_agency_profile = new_broker_agency
  end

  def fire_broker_agency(terminate_on = today)
    return unless active_broker_agency_account
    active_broker_agency_account.end_on = terminate_on
    active_broker_agency_account.is_active = false
    active_broker_agency_account.save!
    employer_broker_fired
    notify_broker_terminated
    broker_fired_confirmation_to_broker
  end

  def broker_fired_confirmation_to_broker
      trigger_notices('broker_fired_confirmation_to_broker')
  end

  def employer_broker_fired
    trigger_notices('employer_broker_fired')
  end

  alias_method :broker_agency_profile=, :hire_broker_agency

  def broker_agency_profile
    return @broker_agency_profile if defined? @broker_agency_profile
    @broker_agency_profile = active_broker_agency_account.broker_agency_profile if active_broker_agency_account.present?
  end

  # def is_ssn_disabled?
  #   no_ssn
  # end

  def active_broker_agency_account
    return @active_broker_agency_account if defined? @active_broker_agency_account
    @active_broker_agency_account = broker_agency_accounts.detect { |account| account.is_active? }
  end

  def active_broker
    if active_broker_agency_account && active_broker_agency_account.writing_agent_id
      Person.where("broker_role._id" => BSON::ObjectId.from_string(active_broker_agency_account.writing_agent_id)).first
    end
  end

  def active_broker_agency_legal_name
    if active_broker_agency_account
      active_broker_agency_account.ba_name
    end
  end

  def memoize_active_broker active_broker_memo
    return unless account = active_broker_agency_account
    if memo = active_broker_memo[account.broker_agency_profile_id] then return memo end
    active_broker_memo[account.broker_agency_profile.id] = active_broker
  end

  # for General Agency
  def hashed_active_general_agency_legal_name gaps
    return  unless account = active_general_agency_account
    gap = gaps.detect{|gap| gap.id == account.general_agency_profile_id}
    gap && gap.legal_name
  end

  def active_general_agency_legal_name
    if active_general_agency_account
      active_general_agency_account.ga_name
    end
  end

  def active_general_agency_account
    general_agency_accounts.active.first
  end

  def general_agency_profile
    return @general_agency_profile if defined? @general_agency_profile
    @general_agency_profile = active_general_agency_account.general_agency_profile if active_general_agency_account.present?
  end

  def hire_general_agency(new_general_agency, broker_role_id = nil, start_on = TimeKeeper.datetime_of_record)

    # commented out the start_on and terminate_on
    # which is same as broker calculation, However it will cause problem
    # start_on later than end_on
    #
    #start_on = start_on.to_date.beginning_of_day
    #if active_general_agency_account.present?
    #  terminate_on = (start_on - 1.day).end_of_day
    #  fire_general_agency!(terminate_on)
    #end
    fire_general_agency!(TimeKeeper.datetime_of_record) if active_general_agency_account.present?
    general_agency_accounts.build(general_agency_profile: new_general_agency, start_on: start_on, broker_role_id: broker_role_id)
    @general_agency_profile = new_general_agency
  end

  def fire_general_agency!(terminate_on = TimeKeeper.datetime_of_record)
    return if active_general_agency_account.blank?
    general_agency_accounts.active.update_all(aasm_state: "inactive", end_on: terminate_on)
    notify_general_agent_terminated
    self.trigger_notices("general_agency_terminated")
  end
  alias_method :general_agency_profile=, :hire_general_agency

  def employee_roles
    return @employee_roles if defined? @employee_roles
    @employee_roles = EmployeeRole.find_by_employer_profile(self)
  end

  def notify_general_agent_terminated
    notify("acapi.info.events.employer.general_agent_terminated", {employer_id: self.hbx_id, event_name: "general_agent_terminated"})
  end

  # TODO - turn this in to counter_cache -- see: https://gist.github.com/andreychernih/1082313
  def roster_size
    return @roster_size if defined? @roster_size
    @roster_size = census_employees.active.size
  end

  def active_plan_year
    @active_plan_year if defined? @active_plan_year
    if plan_year = plan_years.published_plan_years_by_date(today).first
      @active_plan_year = plan_year
    end
  end

  def latest_plan_year
    return @latest_plan_year if defined? @latest_plan_year
    @latest_plan_year = plan_years.order_by(:'start_on'.desc).limit(1).only(:plan_years).first
  end

  def draft_plan_year
    plan_years.select{ |py| py.aasm_state == "draft" }
  end

  def published_plan_year
    plan_years.published.last
  end

  def show_plan_year
    renewing_published_plan_year || active_plan_year || published_plan_year
  end

  def active_or_published_plan_year
     published_plan_year
  end

  def active_and_renewing_published
    result = []
    result << active_plan_year  if active_plan_year.present?
    result << renewing_published_plan_year  if renewing_published_plan_year.present?
    result
  end

  def dt_display_plan_year
    plan_years.where(:aasm_state.nin => ['canceled','renewing_canceled']).order_by(:"start_on".desc).first || latest_plan_year
  end

  def plan_year_drafts
    plan_years.reduce([]) { |set, py| set << py if py.aasm_state == "draft"; set }
  end

  def is_conversion?
    self.profile_source.to_s == "conversion"
  end

  def is_conversion?
    self.profile_source.to_s == "conversion"
  end

  def is_converting?
    self.is_conversion? && published_plan_year.present? && published_plan_year.is_conversion
  end

  def find_plan_year_by_effective_date(target_date)
    plan_year = (plan_years.published + plan_years.renewing_published_state + plan_years.where(:aasm_state.in => ["expired", "termination_pending"])).detect do |py|
      (py.start_on.beginning_of_day..py.end_on.end_of_day).cover?(target_date)
    end

    (plan_year.present? && plan_year.external_plan_year?) ? renewing_published_plan_year : plan_year
  end

  def earliest_plan_year_start_on_date
   plan_years = (self.plan_years.published_or_renewing_published + self.plan_years.where(:aasm_state.in => ["expired", "terminated"]))
   plan_years.reject!{|py| py.can_be_migrated? }
   plan_year = plan_years.sort_by {|test| test[:start_on]}.first
   if !plan_year.blank?
     plan_year.start_on
   end
 end

  def billing_plan_year(billing_date = nil)
    billing_report_date = billing_date || TimeKeeper.date_of_record.next_month
    plan_year = find_plan_year_by_effective_date(billing_report_date)

    if billing_date.blank?
      if plan_year.blank?
        if plan_year = (plan_years.published + plan_years.renewing_published_state).detect{|py| py.start_on > billing_report_date && py.open_enrollment_contains?(TimeKeeper.date_of_record) }
          billing_report_date = plan_year.start_on
        end
      end

      if plan_year.blank?
        if plan_year = find_plan_year_by_effective_date(TimeKeeper.date_of_record)
          billing_report_date = TimeKeeper.date_of_record
        end
      end

      if plan_year.blank?
        if plan_year = (plan_years.published + plan_years.renewing_published_state).detect{|py| py.start_on > billing_report_date }
          billing_report_date = plan_year.start_on
        end
      end
    end

    return plan_year, billing_report_date
  end

  def enrollments_for_billing(billing_date = nil)
    plan_year, billing_report_date = billing_plan_year(billing_date)
    hbx_enrollments = []

    if plan_year.present?
      hbx_enrollments = plan_year.hbx_enrollments_by_month(billing_report_date).compact
      # hbx_enrollments.reject!{|enrollment| !enrollment.census_employee.is_active?}
    end

    hbx_enrollments
  end

  def find_plan_year(id)
    plan_years.where(id: id).first
  end

  def renewing_published_plan_year
    plan_years.renewing_published_state.first
  end

  def renewing_plan_year
    plan_years.renewing.first
  end

  def is_transmit_xml_button_disabled?
    if self.renewing_plan_year.present?
      binder_criteria_satisfied?
    else
      !self.renewing_plan_year.present? && !self.binder_paid?
    end
  end

  def binder_criteria_satisfied?
    show_plan_year.present? &&
    participation_count == 0 &&
    non_owner_participation_criteria_met?
  end

  def participation_count
    show_plan_year.additional_required_participants_count
  end

  def non_owner_participation_criteria_met?
    show_plan_year.assigned_census_employees_without_owner.present?
  end

  def renewing_plan_year_drafts
    plan_years.reduce([]) { |set, py| set << py if py.aasm_state == "renewing_draft"; set }
  end

  def is_primary_office_local?
    organization.primary_office_location.address.state.to_s.downcase == Settings.aca.state_abbreviation.to_s.downcase
  end

  def build_plan_year_from_quote(quote_claim_code, import_census_employee=false)
    quote = Quote.where("claim_code" => quote_claim_code, "aasm_state" => "published").first

    # Perform quote link if claim_code is valid
    if quote.present? && !quote_claim_code.blank? && quote.published?

      plan_year = self.plan_years.build({
        start_on: (TimeKeeper.date_of_record + 2.months).beginning_of_month, end_on: ((TimeKeeper.date_of_record + 2.months).beginning_of_month + 1.year) - 1.day,
        open_enrollment_start_on: TimeKeeper.date_of_record, open_enrollment_end_on: (TimeKeeper.date_of_record + 1.month).beginning_of_month + 9.days,
        fte_count: quote.member_count
        })

      benefit_group_mapping = Hash.new

      # Build each quote benefit group from quote
      quote.quote_benefit_groups.each do |quote_benefit_group|
        benefit_group = plan_year.benefit_groups.build({plan_option_kind: quote_benefit_group.plan_option_kind, title: quote_benefit_group.title, description: "Linked from Quote with claim code " + quote_claim_code })

        # map quote benefit group to newly created plan year benefit group so it can be assigned to census employees if imported
        benefit_group_mapping[quote_benefit_group.id.to_s] = benefit_group.id

        # Assign benefit group plan information (HEALTH)
        benefit_group.lowest_cost_plan_id = quote_benefit_group.published_lowest_cost_plan
        benefit_group.reference_plan_id = quote_benefit_group.published_reference_plan
        benefit_group.highest_cost_plan_id = quote_benefit_group.published_highest_cost_plan
        benefit_group.elected_plan_ids.push(quote_benefit_group.published_reference_plan)
        benefit_group.dental_plan_option_kind = quote_benefit_group.dental_plan_option_kind
        benefit_group.relationship_benefits = quote_benefit_group.quote_relationship_benefits.map{|x| x.attributes.slice(:offered,:relationship, :premium_pct)}

        # Assign benefit group plan information (DENTAL )
        benefit_group.dental_reference_plan_id = quote_benefit_group.published_dental_reference_plan
        benefit_group.elected_dental_plan_ids = quote_benefit_group.elected_dental_plan_ids

        benefit_group.dental_relationship_benefits = quote_benefit_group.quote_dental_relationship_benefits.map{|x| x.attributes.slice(:offered,:relationship, :premium_pct)}

      end

      if plan_year.save!

        quote.claim!

        if import_census_employee == true
          quote.quote_households.each do |qhh|
            qhh_employee = qhh.employee
            if qhh.employee.present?
                quote_employee = qhh.employee
                ce = CensusEmployee.new("employer_profile_id" => self.id, "first_name" => quote_employee.first_name, "last_name" => quote_employee.last_name, "dob" => quote_employee.dob, "hired_on" => plan_year.start_on)
                ce.find_or_create_benefit_group_assignment(plan_year.benefit_groups.find(benefit_group_mapping[qhh.quote_benefit_group_id.to_s].to_s).to_a)

                qhh.dependents.each do |qhh_dependent|
                  ce.census_dependents << CensusDependent.new(
                    last_name: qhh_dependent.last_name, first_name: qhh_dependent.first_name, dob: qhh_dependent.dob, employee_relationship: qhh_dependent.employee_relationship
                    )
                end
                ce.save(:validate => false)
            end
          end
        end

        return true

      end

    end

    return false
  end

  def is_renewal_transmission_eligible?
    renewing_plan_year.present? && renewing_plan_year.renewing_enrolled?
  end

  def is_renewal_carrier_drop?
    if is_renewal_transmission_eligible?
      (active_plan_year.carriers_offered - renewing_plan_year.carriers_offered).any? || (active_plan_year.dental_carriers_offered - renewing_plan_year.dental_carriers_offered).any?
    else
      true
    end
  end

  ## Class methods
  class << self

    def list_embedded(parent_list)
      parent_list.reduce([]) { |list, parent_instance| list << parent_instance.employer_profile }
    end

    def all
      list_embedded Organization.exists(employer_profile: true).order_by([:legal_name]).to_a
    end

    def first
      all.first
    end

    def last
      all.last
    end

    def find(id)
      organizations = Organization.where("employer_profile._id" => BSON::ObjectId.from_string(id))
      organizations.size > 0 ? organizations.first.employer_profile : nil
    rescue
      log("Can not find employer_profile with id #{id}", {:severity => "error"})
      nil
    end

    def find_by_fein(fein)
      organization = Organization.where(fein: fein).first
      organization.present? ? organization.employer_profile : nil
    end

    def find_by_broker_agency_profile(broker_agency_profile)
      raise ArgumentError.new("expected BrokerAgencyProfile") unless broker_agency_profile.is_a?(BrokerAgencyProfile)
      orgs = Organization.by_broker_agency_profile(broker_agency_profile.id)
      orgs.collect(&:employer_profile)
    end

    def find_by_general_agency_profile(general_agency_profile)
      raise ArgumentError.new("expected GeneralAgencyProfile") unless general_agency_profile.is_a?(GeneralAgencyProfile)
      orgs = Organization.by_general_agency_profile(general_agency_profile.id)
      orgs.collect(&:employer_profile)
    end

    def find_by_writing_agent(writing_agent)
      raise ArgumentError.new("expected BrokerRole") unless writing_agent.is_a?(BrokerRole)
      orgs = Organization.by_broker_role(writing_agent.id)
      orgs.collect(&:employer_profile)
    end

    def find_census_employee_by_person(person)
      return [] if person.ssn.blank? || person.dob.blank?
      CensusEmployee.matchable(person.ssn, person.dob)
    end

    def organizations_for_low_enrollment_notice(new_date)
      Organization.where(:"employer_profile.plan_years" =>
        { :$elemMatch => {
          :"aasm_state".in => ["enrolling", "renewing_enrolling"],
          :"open_enrollment_end_on" => new_date+2.days
          }
      })

    end

    def organizations_for_open_enrollment_begin(new_date)
      Organization.where(:"employer_profile.plan_years" =>
          { :$elemMatch => {
           :"open_enrollment_start_on".lte => new_date,
           :"open_enrollment_end_on".gte => new_date,
           :"aasm_state".in => ['published', 'renewing_published']
         }
      })
    end

    def organizations_for_open_enrollment_end(new_date)
      Organization.where(:"employer_profile.plan_years" =>
          { :$elemMatch => {
           :"open_enrollment_end_on".lt => new_date,
           :"start_on".gt => new_date,
           :"aasm_state".in => ['published', 'renewing_published', 'enrolling', 'renewing_enrolling']
         }
      })
    end

    def organizations_for_plan_year_begin(new_date)
      Organization.where(:"employer_profile.plan_years" =>
        { :$elemMatch => {
          :"start_on".lte => new_date,
          :"end_on".gt => new_date,
          :"aasm_state".in => (PlanYear::PUBLISHED + PlanYear::RENEWING_PUBLISHED_STATE - ['active'])
        }
      })
    end

    def organizations_for_plan_year_end(new_date)
      Organization.where(:"employer_profile.plan_years" =>
        { :$elemMatch => {
          :"end_on".lt => new_date,
          :"aasm_state".in => PlanYear::PUBLISHED + PlanYear::RENEWING_PUBLISHED_STATE
        }
      })
    end

    def initial_employers_enrolled_plan_year_state(start_on)
      Organization.where(:"employer_profile.plan_years" => 
        { :$elemMatch => { 
          :"start_on" => start_on,
          :aasm_state => "enrolled"
          }
        })
    end

    def initial_employers_reminder_to_publish(start_on)
      Organization.where(:"employer_profile.plan_years" =>
        { :$elemMatch => {
          :"start_on" => start_on,
          :"aasm_state" => "draft"
        }
      })
    end

    def organizations_eligible_for_renewal(new_date)
      months_prior_to_effective = Settings.aca.shop_market.renewal_application.earliest_start_prior_to_effective_on.months * -1

      Organization.where(:"employer_profile.plan_years" =>
        { :$elemMatch => {
          :"start_on" => (new_date + months_prior_to_effective.months) - 1.year,
          :"aasm_state".in => PlanYear::PUBLISHED
        }
      })
    end

    def organizations_for_force_publish(new_date)
      Organization.where({
        :'employer_profile.plan_years' =>
        { :$elemMatch => {
          :start_on => new_date.next_month.beginning_of_month,
          :aasm_state => 'renewing_draft'
          }}
      })
    end

    def renewal_employers_reminder_to_publish(start_on)
      Organization.where({
        :'employer_profile.plan_years' =>
        { :$elemMatch => {
          :start_on => start_on,
          :aasm_state => 'renewing_draft'
          }}
      })
    end

    def terminate_scheduled_plan_years

      organizations = Organization.where(:"employer_profile.plan_years" => {:$elemMatch => {:end_on.lt => TimeKeeper.date_of_record, :aasm_state => "termination_pending"}})
      organizations.each do |org|
        begin
          plan_years = org.employer_profile.plan_years.where(:aasm_state => "termination_pending", :end_on.lt => TimeKeeper.date_of_record)
          plan_years.each do |py|
            py.terminate!(py.end_on)
            org.employer_profile.revert_application! if py.terminated? && org.employer_profile.may_revert_application?
          end
        rescue Exception => e
          Rails.logger.error { "Unable to terminate plan year for #{org.legal_name} due to #{e.inspect}" }
        end
      end
    end

    def advance_day(new_date)
      if !Rails.env.test?

        # Terminates scheduled plan years
        EmployerProfile.terminate_scheduled_plan_years

        plan_year_renewal_factory = Factories::PlanYearRenewalFactory.new
        organizations_eligible_for_renewal(new_date).each do |organization|
          begin
            plan_year_renewal_factory.employer_profile = organization.employer_profile
            plan_year_renewal_factory.is_congress = false # TODO handle congress differently
            plan_year_renewal_factory.renew
          rescue Exception => e
            Rails.logger.error { "Unable to renew plan year organizations_eligible_for_renewal for #{organization.legal_name} due to #{e}" }
          end
        end

        open_enrollment_factory = Factories::EmployerOpenEnrollmentFactory.new
        open_enrollment_factory.date = new_date

        organizations_for_open_enrollment_begin(new_date).each do |organization|
          begin
            open_enrollment_factory.employer_profile = organization.employer_profile
            open_enrollment_factory.begin_open_enrollment
          rescue Exception => e
            Rails.logger.error { "Unable to begin_open_enrollment begin_open_enrollment begin_open_enrollment #{organization.legal_name} due to #{e}" }
          end
        end

        organizations_for_open_enrollment_end(new_date).each do |organization|
          begin
            open_enrollment_factory.employer_profile = organization.employer_profile
            open_enrollment_factory.end_open_enrollment
          rescue Exception => e
            Rails.logger.error { "Unable to end_open_enrollment end_open_enrollment end_open_enrollment #{organization.legal_name} due to #{e}" }
          end
        end

        # Reminder notices to renewing employers to publish thier plan years.
        start_on = new_date.next_month.beginning_of_month
        if new_date.day == Settings.aca.shop_market.renewal_application.publish_due_day_of_month-7
          renewal_employers_reminder_to_publish(start_on).each do |organization|
            begin
              organization.employer_profile.trigger_notices("renewal_employer_first_reminder_to_publish_plan_year", "acapi_trigger" => true)
            rescue Exception => e
              Rails.logger.error { "Unable to deliver first reminder notice to publish plan year to renewing employer #{organization.legal_name} due to #{e}" }
            end
          end
        elsif new_date.day == Settings.aca.shop_market.renewal_application.publish_due_day_of_month-6
          renewal_employers_reminder_to_publish(start_on).each do |organization|
            begin
              organization.employer_profile.trigger_notices("renewal_employer_second_reminder_to_publish_plan_year", "acapi_trigger" => true)
            rescue Exception => e
              Rails.logger.error { "Unable to deliver second reminder notice to publish plan year to renewing employer #{organization.legal_name} due to #{e}" }
            end
          end
        elsif new_date.day == Settings.aca.shop_market.renewal_application.publish_due_day_of_month-2
          renewal_employers_reminder_to_publish(start_on).each do |organization|
            begin
              organization.employer_profile.trigger_notices("renewal_employer_final_reminder_to_publish_plan_year", "acapi_trigger" => true)
            rescue Exception => e
              Rails.logger.error { "Unable to deliver final reminder notice to publish plan year to renewing employer #{organization.legal_name} due to #{e}" }
            end
          end
        end

        employer_enroll_factory = Factories::EmployerEnrollFactory.new
        employer_enroll_factory.date = new_date

        organizations_for_plan_year_begin(new_date).each do |organization|
          begin
            puts "START START FOR #{organization.legal_name} - #{Time.now}"
            employer_enroll_factory.employer_profile = organization.employer_profile
            employer_enroll_factory.begin
            puts "PROCESSED START FOR #{organization.legal_name} - #{Time.now}"
          rescue Exception => e
            Rails.logger.error { "Error found for employer - #{organization.legal_name} during plan year begin" }
          end
        end

        organizations_for_plan_year_end(new_date).each do |organization|
          begin
            puts "START END FOR #{organization.legal_name} - #{Time.now}"
            employer_enroll_factory.employer_profile = organization.employer_profile
            employer_enroll_factory.end
            puts "PROCESSED END FOR #{organization.legal_name} - #{Time.now}"
          rescue Exception => e
            Rails.logger.error { "Error found for employer - #{organization.legal_name} during plan year end" }
          end
        end

        if new_date.day == Settings.aca.shop_market.renewal_application.force_publish_day_of_month
          organizations_for_force_publish(new_date).each do |organization|
            begin
              plan_year = organization.employer_profile.plan_years.where(:aasm_state => 'renewing_draft').first
              plan_year.force_publish!
              Rails.logger.info { "FORCE PUBLISHED PY FOR #{organization.legal_name} --- #{plan_year.aasm_state}"  }
            rescue Exception => e
              Rails.logger.error { "Error force publishing renewing plan year for #{organization.legal_name} due to #{e}" }
            end
          end
        end

        organizations_for_low_enrollment_notice(new_date).each do |organization|
          begin
            plan_year = organization.employer_profile.plan_years.where(:aasm_state.in => ["enrolling", "renewing_enrolling"]).first
            #exclude congressional employees
            next if ((plan_year.benefit_groups.any?{|bg| bg.is_congress?}) || (plan_year.effective_date.yday == 1))
            if plan_year.enrollment_ratio < Settings.aca.shop_market.employee_participation_ratio_minimum
              organization.employer_profile.trigger_notices("low_enrollment_notice_for_employer", "acapi_trigger" => true)
            end
          rescue Exception => e
            Rails.logger.error { "Unable to deliver Low Enrollment Notice to #{organization.legal_name} due to #{e}" }
          end
        end

        if Settings.aca.shop_market.transmit_scheduled_employers
          if new_date.day == Settings.aca.shop_market.employer_transmission_day_of_month
            begin
              transmit_scheduled_employers(new_date)
            rescue Exception => e
              Rails.logger.error { "Error transmitting scheduled employers due to #{e}" }
            end
          end
        end

        #Initial employer reminder notices to publish plan year.
        start_on = (new_date+2.months).beginning_of_month
        start_on_1 = (new_date+1.month).beginning_of_month
        if new_date+2.days == start_on.last_month
          initial_employers_reminder_to_publish(start_on).each do |organization|
            begin
              organization.employer_profile.trigger_notices("initial_employer_first_reminder_to_publish_plan_year", "acapi_trigger" => true)
            rescue Exception => e
              Rails.logger.error { "Unable to send first reminder notice to publish plan year to #{organization.legal_name} due to following error #{e}" }
            end
          end
        elsif new_date+1.day == start_on.last_month
          initial_employers_reminder_to_publish(start_on).each do |organization|
            begin
              organization.employer_profile.trigger_notices("initial_employer_second_reminder_to_publish_plan_year", "acapi_trigger" => true)
            rescue Exception => e
              Rails.logger.error { "Unable to send second reminder notice to publish plan year to #{organization.legal_name} due to following error #{e}" }
            end
          end
        else
          plan_year_due_date = Date.new(start_on_1.prev_month.year, start_on_1.prev_month.month, Settings.aca.shop_market.initial_application.publish_due_day_of_month)
          if (new_date + 2.days) == plan_year_due_date
            initial_employers_reminder_to_publish(start_on_1).each do |organization|
              begin
                organization.employer_profile.trigger_notices("initial_employer_final_reminder_to_publish_plan_year", "acapi_trigger" => true)
              rescue Exception => e
                Rails.logger.error { "Unable to send final reminder notice to publish plan year to #{organization.legal_name} due to following error #{e}" }
              end
            end
          end
        end

        if new_date.prev_day.day == Settings.aca.shop_market.initial_application.quiet_period_end_on
          effective_on = new_date.prev_day.next_month.beginning_of_month.strftime("%Y-%m-%d")
          notify("acapi.info.events.employer.initial_employer_quiet_period_ended", {:effective_on => effective_on})
        end

       #initial Employer's missing binder payment due date notices to Employer's and active Employee's.
        start_on_for_missing_binder_payments = TimeKeeper.date_of_record.next_month.beginning_of_month
        binder_next_day = PlanYear.calculate_open_enrollment_date(start_on_for_missing_binder_payments)[:binder_payment_due_date].next_day
        if new_date == binder_next_day
          initial_employers_enrolled_plan_year_state(start_on_for_missing_binder_payments).each do |org|
            if !org.employer_profile.binder_paid?
              notice_for_missing_binder_payment(org)
            end
          end
        end
      end       

      # Employer activities that take place monthly - on first of month
      if new_date.day == 1
        orgs = Organization.exists(:"employer_profile.employer_profile_account._id" => true).not_in(:"employer_profile.employer_profile_account.aasm_state" => %w(canceled terminated))
        orgs.each do |org|
          org.employer_profile.employer_profile_account.advance_billing_period! if org.employer_profile.employer_profile_account.may_advance_billing_period?
          # if org.employer_profile.active_plan_year.present?
          #   Factories::EmployerRenewal(org.employer_profile) if org.employer_profile.today == (org.employer_profile.active_plan_year.end_on - 3.months + 1.day)
          # end
        end
      end

      # Find employers with events today and trigger their respective workflow states
      appeal_period = (Settings.
                          aca.
                          shop_market.
                          initial_application.
                          appeal_period_after_application_denial.
                          to_hash
                        )

      # Negate period value to query past date
      appeal_period.each {|k,v| appeal_period[k] = (v * -1) }

      ineligible_period = (Settings.
                              aca.
                              shop_market.
                              initial_application.
                              ineligible_period_after_application_denial.
                              to_hash
                            )

      # Negate period value to query past date
      ineligible_period.each {|k,v| ineligible_period[k] = (v * -1) }

      orgs = Organization.or(
        {:"employer_profile.plan_years.start_on" => new_date},
        {:"employer_profile.plan_years.end_on" => new_date - 1.day},
        {:"employer_profile.plan_years.open_enrollment_start_on" => new_date},
        {:"employer_profile.plan_years.open_enrollment_end_on" => new_date - 1.day},
        {:"employer_profile.workflow_state_transitions".elem_match => {
            "$and" => [
              {:transition_at.gte => (new_date.advance(ineligible_period).beginning_of_day )},
              {:transition_at.lte => (new_date.advance(ineligible_period).end_of_day)},
              {:to_state => "ineligible"}
            ]
          }
        }
      )

      orgs.each do |org|
        org.employer_profile.today = new_date
        org.employer_profile.advance_date! if org.employer_profile.may_advance_date?
        plan_year = org.employer_profile.published_plan_year
        plan_year.advance_date! if plan_year && plan_year.may_advance_date?
        plan_year
      end
    end
  end

  def self.transmit_scheduled_employers(new_date, feins=[])
    start_on = new_date.next_month.beginning_of_month
    employer_collection = Organization
    employer_collection = Organization.where(:fein.in => feins) if feins.any?

    employer_collection.where(:"employer_profile.plan_years" => {
      :$elemMatch => {:start_on => start_on.prev_year, :aasm_state => 'active'}
      }).each do |org|

      employer_profile = org.employer_profile
      employer_profile.transmit_renewal_eligible_event if employer_profile.is_renewal_transmission_eligible?
      employer_profile.transmit_renewal_carrier_drop_event if employer_profile.is_renewal_carrier_drop?
    end

    employer_collection.where(:"employer_profile.plan_years" => {
      :$elemMatch => {:start_on => start_on, :aasm_state => 'enrolled'}
      }, :"employer_profile.aasm_state".in => ['binder_paid']).each do |org|

      org.employer_profile.transmit_initial_eligible_event
    end
  end

  def revert_plan_year
    plan_year.revert
  end

  def default_benefit_group
    plan_year_with_default = plan_years.where("benefit_groups.default" => true).order_by([:start_on]).last
    return unless plan_year_with_default
    plan_year_with_default.benefit_groups.detect{|bg| bg.default }
  end

## TODO - anonymous shopping
# no fein required
# no SSNs, names, relationships, required
# build-in geographic rating and tobacco - set defaults

## TODO - Broker tools
# sample census profiles
# ability to create library of templates for employer profiles

  # Workflow for self service
  aasm do
    state :applicant, initial: true
    state :registered                 # Employer has submitted valid application
    state :eligible                   # Employer has completed enrollment and is eligible for coverage
    state :binder_paid, :after_enter => [:notify_binder_paid,:notify_initial_binder_paid]
    state :enrolled                   # Employer has completed eligible enrollment, paid the binder payment and plan year has begun
  # state :lapsed                     # Employer benefit coverage has reached end of term without renewal
  state :suspended                  # Employer's benefit coverage has lapsed due to non-payment
    state :ineligible                 # Employer is unable to obtain coverage on the HBX per regulation or policy

    event :advance_date do
      transitions from: :ineligible, to: :applicant, :guard => :has_ineligible_period_expired?
    end

    event :application_accepted, :after => :record_transition do
      transitions from: [:registered], to: :registered
      transitions from: [:applicant, :ineligible], to: :registered
    end

    event :application_declined, :after => :record_transition do
      transitions from: :applicant, to: :ineligible
      transitions from: :ineligible, to: :ineligible
    end

    event :application_expired, :after => :record_transition do
      transitions from: :registered, to: :applicant
    end

    event :enrollment_ratified, :after => :record_transition do
      transitions from: [:registered, :ineligible], to: :eligible, :after => :initialize_account
    end

    event :enrollment_expired, :after => :record_transition do
      transitions from: :eligible, to: :applicant
    end

    event :binder_credited, :after => :record_transition do
      transitions from: :eligible, to: :binder_paid
    end

    event :binder_reversed, :after => :record_transition do
      transitions from: :binder_paid, to: :eligible
    end

    event :enroll_employer, :after => :record_transition do
      transitions from: :binder_paid, to: :enrolled
    end

    event :enrollment_denied, :after => :record_transition do
      transitions from: [:registered, :enrolled], to: :applicant
    end

    event :benefit_suspended, :after => :record_transition do
      transitions from: :enrolled, to: :suspended, :after => :suspend_benefit
    end

    event :employer_reinstated, :after => :record_transition do
      transitions from: :suspended, to: :enrolled
    end

    event :benefit_terminated, :after => :record_transition do
      transitions from: [:enrolled, :suspended], to: :applicant
    end

    event :benefit_canceled, :after => :record_transition do
      transitions from: :eligible, to: :applicant, :after => :cancel_benefit
    end

    # Admin capability to reset an Employer to applicant state
    event :revert_application, :after => :record_transition do
      transitions from: [:registered, :eligible, :ineligible, :suspended, :binder_paid, :enrolled], to: :applicant
    end

    event :force_enroll, :after => :record_transition do
      transitions from: [:applicant, :eligible, :registered], to: :enrolled
    end
  end

  after_update :broadcast_employer_update, :notify_broker_added, :notify_general_agent_added

  def broadcast_employer_update
    if previous_states.include?(:binder_paid) || (aasm_state.to_sym == :binder_paid)
      notify(EMPLOYER_PROFILE_UPDATED_EVENT_NAME, {:employer_id => self.hbx_id})
    end
  end

  def previous_states
    self.workflow_state_transitions.map(&:from_state).uniq.map(&:to_sym)
  end

  def within_open_enrollment_for?(t_date, effective_date)
    plan_years.any? do |py|
      py.open_enrollment_contains?(t_date) &&
        py.coverage_period_contains?(effective_date)
    end
  end

  def latest_workflow_state_transition
    workflow_state_transitions.order_by(:'transition_at'.desc).limit(1).first
  end

  def enrollment_ineligible_period_expired?
    if latest_workflow_state_transition.to_state == "ineligible"
      (latest_workflow_state_transition.transition_at.to_date.advance(Settings.
                                                                          aca.
                                                                          shop_market.
                                                                          initial_application.
                                                                          ineligible_period_after_application_denial.
                                                                          to_hash
                                                                        )
                                                                      ) <= TimeKeeper.date_of_record
    else
      true
    end
  end

  # def is_eligible_to_shop?
  #   registered? or published_plan_year.enrolling?
  # end

  def self.update_status_to_binder_paid(organization_ids)
    organization_ids.each do |id|
      if org = Organization.find(id)
        org.employer_profile.update_attribute(:aasm_state, "binder_paid")
        self.initial_employee_plan_selection_confirmation(org)
      end
    end
  end

  def self.initial_employee_plan_selection_confirmation(org)
    begin
      if org.employer_profile.is_new_employer?
        census_employees = org.employer_profile.census_employees.non_terminated
        census_employees.each do |ce|
          if ce.active_benefit_group_assignment.hbx_enrollment.present? && ce.active_benefit_group_assignment.hbx_enrollment.effective_on == org.employer_profile.plan_years.where(:aasm_state.in => ["enrolled", "enrolling"]).first.start_on
            ShopNoticesNotifierJob.perform_later(ce.id.to_s, "initial_employee_plan_selection_confirmation", "acapi_trigger" => true )
          end
        end
      end
    rescue Exception => e
      Rails.logger.error {"Unable to deliver initial_employee_plan_selection_confirmation to employees of #{org.legal_name} due to #{e.backtrace}"}
    end
  end

  def self.notice_for_missing_binder_payment(org)
    org.employer_profile.trigger_notices("initial_employer_no_binder_payment_received", "acapi_trigger" => true)
    org.employer_profile.census_employees.active.each do |ce|
      begin
        ShopNoticesNotifierJob.perform_later(ce.id.to_s, "notice_to_ee_that_er_plan_year_will_not_be_written", "acapi_trigger" =>  true )
      rescue Exception => e
        (Rails.logger.error {"Unable to deliver notice_to_ee_that_er_plan_year_will_not_be_written to #{ce.full_name} due to #{e}"}) unless Rails.env.test?
      end
    end
  end

  def is_new_employer?
    !renewing_plan_year.present? #&& TimeKeeper.date_of_record > 10
  end

  def is_renewing_employer?
     renewing_plan_year.present? #&& TimeKeeper.date_of_record.day > 13
  end

  def has_next_month_plan_year?
    show_plan_year.present? && (show_plan_year.start_on == (TimeKeeper.date_of_record.next_month).beginning_of_month)
  end

  def is_eligible_to_enroll?
    published_plan_year.enrolling?
  end

  def notify_binder_paid
    notify(BINDER_PREMIUM_PAID_EVENT_NAME, {:employer_id => self.hbx_id})
  end

  def notify_initial_binder_paid
    notify("acapi.info.events.employer.benefit_coverage_initial_binder_paid", {employer_id: self.hbx_id, event_name: "benefit_coverage_initial_binder_paid"})
  end

  def notify_broker_added
    changed_fields = broker_agency_accounts.map(&:changed_attributes).map(&:keys).flatten.compact.uniq
    if changed_fields.present? &&  changed_fields.include?("start_on")
      notify("acapi.info.events.employer.broker_added", {employer_id: self.hbx_id, event_name: "broker_added"})
    end
  end

  def notify_broker_terminated
    notify("acapi.info.events.employer.broker_terminated", {employer_id: self.hbx_id, event_name: "broker_terminated"})
  end

  def notify_general_agent_added
    changed_fields = general_agency_accounts.map(&:changed_attributes).map(&:keys).flatten.compact.uniq
    if changed_fields.present? && changed_fields.include?("start_on")
      notify("acapi.info.events.employer.general_agent_added", {employer_id: self.hbx_id, event_name: "general_agent_added"})
    end
  end

  def transmit_initial_eligible_event
    notify(INITIAL_EMPLOYER_TRANSMIT_EVENT, {employer_id: self.hbx_id, event_name: INITIAL_APPLICATION_ELIGIBLE_EVENT_TAG})
  end

  def transmit_renewal_eligible_event
    notify(RENEWAL_EMPLOYER_TRANSMIT_EVENT, {employer_id: self.hbx_id, event_name: RENEWAL_APPLICATION_ELIGIBLE_EVENT_TAG})
  end

  def transmit_renewal_carrier_drop_event
    notify(RENEWAL_EMPLOYER_CARRIER_DROP_EVENT, {employer_id: self.hbx_id, event_name: RENEWAL_APPLICATION_CARRIER_DROP_EVENT_TAG})
  end

  def conversion_employer?
    !self.converted_from_carrier_at.blank?
  end

  def self.by_hbx_id(an_hbx_id)
    org = Organization.where(hbx_id: an_hbx_id, employer_profile: {"$exists" => true})
    return nil unless org.any?
    org.first.employer_profile
  end

  def is_conversion?
    self.profile_source == "conversion"
  end

  def generate_and_deliver_checkbook_urls_for_employees
    census_employees.each do |census_employee|
      census_employee.generate_and_deliver_checkbook_url
    end
  end

  def generate_checkbook_notices
    ShopNoticesNotifierJob.perform_later(self.id.to_s, "out_of_pocker_url_notifier")
  end

  def trigger_notices(event, options = {})
    begin
      ShopNoticesNotifierJob.perform_later(self.id.to_s, event, options)
    rescue Exception => e
      Rails.logger.error { "Unable to deliver #{event.humanize} - notice to #{self.legal_name} due to #{e}" }
    end
  end

private
  def has_ineligible_period_expired?
    ineligible? and (latest_workflow_state_transition.transition_at.to_date + 90.days <= TimeKeeper.date_of_record)
  end

  def cancel_benefit
    published_plan_year.cancel
  end

  def suspend_benefit
    published_plan_year.suspend
  end

  def terminate_benefit
    published_plan_year.terminate
  end

  def record_transition
    self.workflow_state_transitions << WorkflowStateTransition.new(
      from_state: aasm.from_state,
      to_state: aasm.to_state,
      event: aasm.current_event
    )
  end
   
  # TODO - fix premium amount
  def initialize_account
    if employer_profile_account.blank?
      self.build_employer_profile_account
      employer_profile_account.next_premium_due_on = (published_plan_year.start_on.last_month) + (Settings.aca.shop_market.binder_payment_due_on).days
      employer_profile_account.next_premium_amount = 100
      # census_employees.covered
      save
    end
  end

  def build_nested_models
    build_inbox if inbox.nil?
  end

  def save_associated_nested_models
  end

  def save_inbox
    welcome_subject = "Welcome to #{Settings.site.short_name}"
    welcome_body = "#{Settings.site.short_name} is the #{Settings.aca.state_name}'s on-line marketplace to shop, compare, and select health insurance that meets your health needs and budgets."
    @inbox.save
    @inbox.messages.create(subject: welcome_subject, body: welcome_body)
  end

  def effective_date_expired?
    latest_plan_year.effective_date.beginning_of_day == (TimeKeeper.date_of_record.end_of_month + 1).beginning_of_day
  end

  def plan_year_publishable?
    !published_plan_year.is_application_unpublishable?
  end
end