class Family
  require 'autoinc'

  include Mongoid::Document
  include SetCurrentUser
  include Mongoid::Timestamps
  include Sortable
  include Mongoid::Autoinc

  IMMEDIATE_FAMILY = %w(self spouse life_partner child ward foster_child adopted_child stepson_or_stepdaughter stepchild domestic_partner)

  field :version, type: Integer, default: 1
  embeds_many :versions, class_name: self.name, validate: false, cyclic: true, inverse_of: nil

  field :hbx_assigned_id, type: Integer
  increments :hbx_assigned_id, seed: 9999

  field :e_case_id, type: String # Eligibility system foreign key
  field :e_status_code, type: String
  field :application_type, type: String
  field :renewal_consent_through_year, type: Integer # Authorize auto-renewal elibility check through this year (CCYY format)

  field :is_active, type: Boolean, default: true # ApplicationGroup active on the Exchange?
  field :submitted_at, type: DateTime # Date application was created on authority system
  field :updated_by, type: String
  field :status, type: String, default: "" # for aptc block
  field :min_verification_due_date, type: Date, default: nil
  field :vlp_documents_status, type: String

  belongs_to  :person

  embeds_many :family_members, cascade_callbacks: true
  embeds_many :special_enrollment_periods, cascade_callbacks: true
  # embeds_many :irs_groups, cascade_callbacks: true
  embeds_many :households, cascade_callbacks: true, :before_add => :reset_active_household
  embeds_many :broker_agency_accounts, class_name: "BenefitSponsors::Accounts::BrokerAgencyAccount"
  embeds_many :general_agency_accounts
  embeds_many :documents, as: :documentable

  after_initialize :build_household
  before_save :clear_blank_fields

  accepts_nested_attributes_for :special_enrollment_periods, :family_members,
                                :households, :broker_agency_accounts, :general_agency_accounts

  # index({hbx_assigned_id: 1}, {unique: true})
  index({e_case_id: 1}, { sparse: true })
  index({submitted_at: 1})
  index({person_id: 1})
  index({is_active: 1})

  # child model indexes
  index({"family_members._id" => 1})
  index({"family_members.person_id" => 1, hbx_assigned_id: 1})
  index({"family_members.broker_role_id" => 1})
  index({"family_members.is_primary_applicant" => 1})
  index({"family_members.hbx_enrollment_exemption.certificate_number" => 1})

  index({"households.hbx_enrollments.broker_agency_profile_id" => 1}, {sparse: true})
  index({"households.hbx_enrollments.effective_on" => 1})
  index({"households.hbx_enrollments.benefit_group_assignment_id" => 1})
  index({"households.hbx_enrollments.benefit_group_id" => 1})

  index({"households.hbx_enrollments.aasm_state" => 1,
         "households.hbx_enrollments.created_at" => 1},
         {name: "state_and_created"})

    index({"households.hbx_enrollments.kind" => 1,
         "households.hbx_enrollments.aasm_state" => 1,
         "households.hbx_enrollments.effective_on" => 1,
         "households.hbx_enrollments.terminated_on" => 1
         },
         {name: "kind_and_state_and_created_and_terminated"})

  index({"households.hbx_enrollments._id" => 1})
  index({"households.hbx_enrollments.kind" => 1,
         "households.hbx_enrollments.aasm_state" => 1,
         "households.hbx_enrollments.coverage_kind" => 1,
         "households.hbx_enrollments.effective_on" => 1
         },
         {name: "kind_and_state_and_coverage_kind_effective_date"})

  index({
    "households.hbx_enrollments.sponsored_benefit_package_id" => 1,
    "households.hbx_enrollments.sponsored_benefit_id" => 1,
    "households.hbx_enrollments.effective_on" => 1,
    "households.hbx_enrollments.submitted_at" => 1,
    "households.hbx_enrollments.terminated_on" => 1,
    "households.hbx_enrollments.employee_role_id" => 1,
    "households.hbx_enrollments.aasm_state" => 1,
    "households.hbx_enrollments.kind" => 1
  }, {name: "hbx_enrollment_sb_package_lookup"})

  index({"households.hbx_enrollments.plan_id" => 1}, { sparse: true })
  index({"households.hbx_enrollments.writing_agent_id" => 1}, { sparse: true })
  index({"households.hbx_enrollments.hbx_id" => 1})
  index({"households.hbx_enrollments.kind" => 1})
  index({"households.hbx_enrollments.submitted_at" => 1})
  index({"households.hbx_enrollments.effective_on" => 1})
  index({"households.hbx_enrollments.terminated_on" => 1}, { sparse: true })
  index({"households.hbx_enrollments.applied_aptc_amount" => 1})

  index({"households.tax_households.hbx_assigned_id" => 1})
  index({"households.tax_households.effective_starting_on" => 1})
  index({"households.tax_households.effective_ending_on" => 1})

  index({"special_enrollment_periods._id" => 1})

  index({"family_members.person_id" => 1, hbx_assigned_id: 1})

  index({"broker_agency_accounts.broker_agency_profile_id" => 1, "broker_agency_accounts.is_active" => 1}, {name: "broker_families_search_index"})
  # index("households.tax_households_id")

  validates :renewal_consent_through_year,
            numericality: {only_integer: true, inclusion: 2014..2025},
            :allow_nil => true

  after_initialize :build_household

  scope :with_enrollment_hbx_id, ->(enrollment_hbx_id) {
      where("households.hbx_enrollments.hbx_id" => enrollment_hbx_id)
    }

  scope :all_with_single_family_member,     ->{ exists({:'family_members.1' => false}) }
  scope :all_with_multiple_family_members,  ->{ exists({:'family_members.1' => true})  }


  scope :all_current_households,            ->{ exists(households: true).order_by(:start_on.desc).limit(1).only(:_id, :"households._id") }
  scope :all_tax_households,                ->{ exists(:"households.tax_households" => true) }

  scope :by_writing_agent_id,               ->(broker_id){ where(broker_agency_accounts: {:$elemMatch=> {writing_agent_id: broker_id, is_active: true}})}
  scope :by_broker_agency_profile_id,       ->(broker_agency_profile_id) { where(broker_agency_accounts: {:$elemMatch=> {is_active: true, "$or": [{benefit_sponsors_broker_agency_profile_id: broker_agency_profile_id}, {broker_agency_profile_id: broker_agency_profile_id}]}})}
  scope :by_general_agency_profile_id,      ->(general_agency_profile_id) { where(general_agency_accounts: {:$elemMatch=> {general_agency_profile_id: general_agency_profile_id, aasm_state: "active"}})}

  scope :all_plan_shopping,             ->{ exists(:"households.hbx_enrollments" => true) }


  scope :by_datetime_range,                     ->(start_at, end_at){ where(:created_at.gte => start_at).and(:created_at.lte => end_at) }
  scope :all_enrollments,                       ->{  where(:"households.hbx_enrollments.aasm_state".in => HbxEnrollment::ENROLLED_STATUSES) }
  scope :all_enrollments_by_writing_agent_id,   ->(broker_id){ where(:"households.hbx_enrollments.writing_agent_id" => broker_id) }
  scope :all_enrollments_by_benefit_group_id,   ->(benefit_group_id){where(:"households.hbx_enrollments.benefit_group_id" => benefit_group_id) }
  scope :all_enrollments_by_benefit_sponsorship_id,   ->(benefit_sponsorship_id){where(:"households.hbx_enrollments.benefit_sponsorship_id" => benefit_sponsorship_id) }
  scope :by_enrollment_individual_market,       ->{ where(:"households.hbx_enrollments.kind".in => ["individual", "unassisted_qhp", "insurance_assisted_qhp", "streamlined_medicaid", "emergency_medicaid", "hcr_chip"]) }
  scope :by_enrollment_shop_market,             ->{ where(:"households.hbx_enrollments.kind".in => ["employer_sponsored", "employer_sponsored_cobra"]) }
  scope :by_enrollment_renewing,                ->{ where(:"households.hbx_enrollments.aasm_state".in => HbxEnrollment::RENEWAL_STATUSES) }
  scope :by_enrollment_created_datetime_range,  ->(start_at, end_at){ where(:"households.hbx_enrollments.created_at" => { "$gte" => start_at, "$lte" => end_at} )}
  scope :by_enrollment_updated_datetime_range,  ->(start_at, end_at){ where(:"households.hbx_enrollments.updated_at" => { "$gte" => start_at, "$lte" => end_at} )}
  scope :by_enrollment_effective_date_range,    ->(start_on, end_on){ where(:"households.hbx_enrollments.effective_on" => { "$gte" => start_on, "$lte" => end_on} )}
  scope :non_enrolled,                          ->{ where(:"households.hbx_enrollments.aasm_state".nin => HbxEnrollment::ENROLLED_STATUSES) }
  scope :sep_eligible,                          ->{ where(:"active_seps.count".gt => 0) }
  scope :coverage_waived,                       ->{ where(:"households.hbx_enrollments.aasm_state".in => HbxEnrollment::WAIVED_STATUSES) }
  scope :having_unverified_enrollment,          ->{ where(:"households.hbx_enrollments.aasm_state" => "enrolled_contingent")}
  scope :with_all_verifications,                ->{ where(:"households.hbx_enrollments" => {:"$elemMatch" => {:"aasm_state" => "enrolled_contingent", :"review_status" => "ready"}})}
  scope :with_partial_verifications,            ->{ where(:"households.hbx_enrollments" => {:"$elemMatch" => {:"aasm_state" => "enrolled_contingent", :"review_status" => "in review"}})}
  scope :with_no_verifications,                 ->{ where(:"households.hbx_enrollments" => {:"$elemMatch" => {:"aasm_state" => "enrolled_contingent", :"review_status" => "incomplete"}})}
  scope :with_reset_verifications,              ->{ where(:"households.hbx_enrollments.aasm_state" => "enrolled_contingent")}
  scope :vlp_fully_uploaded,                    ->{ where(vlp_documents_status: "Fully Uploaded")}
  scope :vlp_partially_uploaded,                ->{ where(vlp_documents_status: "Partially Uploaded")}
  scope :vlp_none_uploaded,                     ->{ where(:vlp_documents_status.in => ["None",nil])}
  scope :outstanding_verification,              ->{ by_enrollment_individual_market.where(:"households.hbx_enrollments"=>{"$elemMatch"=>{:aasm_state => "enrolled_contingent", :effective_on => { :"$gte" => TimeKeeper.date_of_record.beginning_of_year, :"$lte" =>  TimeKeeper.date_of_record.end_of_year }}}) }

  scope :enrolled_through_benefit_package,      ->(benefit_package) { unscoped.where(
                                                    :"households.hbx_enrollments.aasm_state".in => (HbxEnrollment::ENROLLED_STATUSES + HbxEnrollment::RENEWAL_STATUSES + HbxEnrollment::WAIVED_STATUSES),
                                                    :"households.hbx_enrollments.sponsored_benefit_package_id" => benefit_package._id
                                                  ) }

  scope :all_enrollments_by_benefit_sponsorship_id,   ->(benefit_sponsorship_id){where(:"households.hbx_enrollments.benefit_sponsorship_id" => benefit_sponsorship_id) }
  scope :enrolled_under_benefit_application,    ->(benefit_application) { unscoped.where(
                                                    :"households.hbx_enrollments" => {
                                                      :$elemMatch => {
                                                        :sponsored_benefit_package_id => {"$in" => benefit_application.benefit_packages.pluck(:_id) },
                                                        :aasm_state => {"$nin" => %w(coverage_canceled shopping coverage_terminated) },
                                                        :coverage_kind => "health"
                                                      }
                                                  })}

  def active_broker_agency_account
    broker_agency_accounts.detect { |baa| baa.is_active? }
  end

  def coverage_waived?
    latest_household.hbx_enrollments.any? and latest_household.hbx_enrollments.waived.any?
  end

  def remove_family_search_record
    Searches::FamilySearch.where("id" => self.id).delete_all
  end

  def latest_household
    return households.first if households.size == 1
    households.order_by(:'submitted_at'.desc).limit(1).only(:households).first
  end

  def active_household
    # households.detect { |household| household.is_active? }
    latest_household
  end

  def enrolled_benefits
    # latest_household.try(:enrolled_hbx_enrollments)
  end

  def terminated_benefits
  end

  def renewal_benefits
  end

  def currently_enrolled_plans(enrollment)
    enrolled_plans = active_household.hbx_enrollments.enrolled_and_renewing.by_coverage_kind(enrollment.coverage_kind)

    if enrollment.is_shop?
      bg_ids = enrollment.benefit_group.plan_year.benefit_groups.map(&:id)
      enrolled_plans = enrolled_plans.where(:benefit_group_id.in => bg_ids)
    end

    enrolled_plans.collect(&:plan_id)
  end

  def enrollments
    return [] if  latest_household.blank?
    latest_household.hbx_enrollments.show_enrollments_sans_canceled
  end

  def primary_applicant
    family_members.detect { |family_member| family_member.is_primary_applicant? && family_member.is_active? }
  end

  def primary_family_member=(new_primary_family_member)
    self.primary_family_member.is_primary_applicant = false unless primary_family_member.blank?

    existing_family_member = find_family_member_by_person(new_primary_family_member)
    if existing_family_member.present?
      existing_family_member.is_primary_applicant = true
    else
      add_family_member(new_primary_family_member, is_primary_applicant: true)
    end

    primary_family_member
  end

  # @deprecated Use {primary_applicant}
  alias_method :primary_family_member, :primary_applicant

  def consent_applicant
    family_members.detect { |family_member| family_member.is_consent_applicant? && family_member.is_active? }
  end

  def active_family_members
    family_members.find_all { |family_member| family_member.is_active? }
  end

  def find_family_member_by_person(person)
    family_members.detect { |family_member| family_member.person_id.to_s == person._id.to_s }
  end

  def is_eligible_to_enroll?(options = {})
    current_enrollment_eligibility_reasons(qle: options[:qle]).length > 0
  end

  def current_enrollment_eligibility_reasons(options = {})
    current_special_enrollment_periods.collect do |sep|
      EnrollmentEligibilityReason.new(sep)
    end + current_eligible_open_enrollments(qle: options[:qle])
  end

  def is_under_open_enrollment?
    current_eligible_open_enrollments.length > 0
  end

  def is_under_ivl_open_enrollment?
    current_ivl_eligible_open_enrollments.length > 0
  end

  def is_under_shop_open_enrollment?
    current_shop_eligible_open_enrollments.length > 0
  end

  def current_eligible_open_enrollments(options = {})
    current_shop_eligible_open_enrollments(qle: options[:qle]) + current_ivl_eligible_open_enrollments
  end

  def current_ivl_eligible_open_enrollments
    eligible_open_enrollments = []

    benefit_sponsorship = HbxProfile.current_hbx.try(:benefit_sponsorship)
    (benefit_sponsorship.try(:benefit_coverage_periods) || []).each do |benefit_coverage_period|
      if benefit_coverage_period.open_enrollment_contains?(TimeKeeper.date_of_record)
        eligible_open_enrollments << EnrollmentEligibilityReason.new(benefit_sponsorship)
      end
    end

    eligible_open_enrollments
  end

  def current_shop_eligible_open_enrollments(options = {})
    eligible_open_enrollments = []

    active_employee_roles = primary_applicant.person.active_employee_roles if primary_applicant.present?
    active_employee_roles.each do |employee_role|
      if (benefit_group = employee_role.benefit_group(qle: options[:qle])) &&
        (employer_profile = employee_role.try(:employer_profile))
        employer_profile.try(:published_plan_year).try(:enrolling?) &&
        benefit_group.effective_on_for(employee_role.hired_on) > benefit_group.start_on

        eligible_open_enrollments << EnrollmentEligibilityReason.new(employer_profile)
      end
    end

    eligible_open_enrollments
  end

  def is_under_special_enrollment_period?
    return false if special_enrollment_periods.size == 0
    current_special_enrollment_periods.size > 0
  end

  def active_seps
    special_enrollment_periods.find_all { |sep| sep.is_active? }
  end


  def latest_active_sep
    special_enrollment_periods.order_by(:submitted_at.desc).detect{ |sep| sep.is_active? }
  end

  def active_admin_seps
    special_enrollment_periods.find_all { |sep| sep.is_active? && sep.admin_flag }
  end

  def current_special_enrollment_periods
    return [] if special_enrollment_periods.size == 0
    seps = special_enrollment_periods.order_by(:start_on.desc).only(:special_enrollment_periods)
    seps.reduce([]) { |list, event| list << event if event.is_active?; list }
  end

  def earliest_effective_sep
    special_enrollment_periods.order_by(:effective_on.asc).to_a.detect{ |sep| sep.is_active? }
  end

  def earliest_effective_shop_sep
    special_enrollment_periods.shop_market.order_by(:effective_on.asc).to_a.detect{ |sep| sep.is_active? }
  end

  def earliest_effective_ivl_sep
    special_enrollment_periods.individual_market.order_by(:effective_on.asc).to_a.detect{ |sep| sep.is_active? }
  end

  def latest_shop_sep
    special_enrollment_periods.shop_market.order_by(:submitted_at.desc).to_a.detect{ |sep| sep.is_active? }
  end

  def terminate_date_for_shop_by_enrollment(enrollment=nil)
    if latest_shop_sep.present?
      terminate_date = if latest_shop_sep.qualifying_life_event_kind.reason == 'death'
                         latest_shop_sep.qle_on
                       else
                         latest_shop_sep.qle_on.end_of_month
                       end
      if enrollment.present?
        if enrollment.effective_on > latest_shop_sep.qle_on
          terminate_date = enrollment.effective_on
        elsif enrollment.effective_on >= terminate_date
          terminate_date = TimeKeeper.date_of_record.end_of_month
        end
      end
      terminate_date
    else
      TimeKeeper.date_of_record.end_of_month
    end
  end

  def current_sep
    active_seps.max { |sep| sep.end_on }
  end

  def build_from_employee_role(employee_role)
    build_from_person(employee_role.person)
  end

  def build_from_person(person)
    add_family_member(person, is_primary_applicant: true)
    person.person_relationships.each { |kin| add_family_member(kin.relative) }
    self
  end

  def relate_new_member(person, relationship)
    primary_applicant_person.ensure_relationship_with(person, relationship)
    add_family_member(person)
  end

  def add_family_member(person, **opts)
    is_primary_applicant  = opts[:is_primary_applicant]  || false
    is_coverage_applicant = opts[:is_coverage_applicant] || true
    is_consent_applicant  = opts[:is_consent_applicant]  || false

    existing_family_member = family_members.detect { |fm| fm.person_id.to_s == person.id.to_s }

    if existing_family_member
      active_household.add_household_coverage_member(existing_family_member)
      existing_family_member.is_active = true
      return existing_family_member
    end

    family_member = family_members.build(
        person: person,
        is_primary_applicant: is_primary_applicant,
        is_coverage_applicant: is_coverage_applicant,
        is_consent_applicant: is_consent_applicant
      )

    active_household.add_household_coverage_member(family_member)
    family_member
  end

  # Remove {FamilyMember} referenced by this {Person}
  #
  # @param [ Person ] person The {Person} to remove from the family.
  def remove_family_member(person)
    family_member = find_family_member_by_person(person)
    if family_member.present?
      family_member.is_active = false
      active_household.remove_family_member(family_member)
    end

    family_member
  end

  def person_is_family_member?(person)
    find_family_member_by_person(person).present?
  end

  def dependents
    family_members.reject(&:is_primary_applicant)
  end

  def active_dependents
    family_members.reject(&:is_primary_applicant).find_all { |family_member| family_member.is_active? }
  end

  def people_relationship_map
    map = Hash.new
    people.each do |person|
      map[person] = person_relationships.detect { |r| r.object_person == person.id }.relationship_kind
    end
    map
  end

  def is_active?
    self.is_active
  end

  def find_matching_inactive_member(personish)
    inactive_members = family_members.reject(&:is_active)
    return nil if inactive_members.blank?
    if !personish.ssn.blank?
      inactive_members.detect { |mem| mem.person.ssn == personish.ssn }
    else
      return nil if personish.dob.blank?
      search_dob = personish.dob.strftime("%m/%d/%Y")
      inactive_members.detect do |mem|
        mp = mem.person
        mem_dob = mem.dob.blank? ? nil : mem.dob.strftime("%m/%d/%Y")
        (personish.last_name.downcase.strip == mp.last_name.downcase.strip) &&
          (personish.first_name.downcase.strip == mp.first_name.downcase.strip) &&
          (search_dob == mem_dob)
      end
    end
  end

  def hire_broker_agency(broker_role_id)
    return unless broker_role_id
    existing_agency = current_broker_agency
    broker_role = BrokerRole.find(broker_role_id)
    broker_agency_profile_id = broker_role.benefit_sponsors_broker_agency_profile_id.present? ? broker_role.benefit_sponsors_broker_agency_profile_id : broker_role.broker_agency_profile_id
    terminate_broker_agency if existing_agency
    start_on = Time.now
    broker_agency_account =  BenefitSponsors::Accounts::BrokerAgencyAccount.new(benefit_sponsors_broker_agency_profile_id: broker_agency_profile_id, writing_agent_id: broker_role_id, start_on: start_on, is_active: true)
    broker_agency_accounts.push(broker_agency_account)
    self.save
  end

  def terminate_broker_agency(terminate_on = TimeKeeper.date_of_record)
    if current_broker_agency.present?
      current_broker_agency.update_attributes!(end_on: (terminate_on.to_date - 1.day).end_of_day, is_active: false)
    end
  end

  def current_broker_agency
    broker_agency_accounts.detect { |account| account.is_active? }
  end

  def active_broker_roles
    active_household.hbx_enrollments.reduce([]) { |b, e| b << e.broker_role if e.is_active? && !e.broker_role.blank? } || []
  end

  def any_unverified_enrollments?
    enrollments.verification_needed.any?
  end

  class << self
    # Set the sort order to return families by primary applicant last_name, first_name
    def default_search_order
      [["primary_applicant.name_last", 1], ["primary_applicant.name_first", 1]]
    end

    def expire_individual_market_enrollments
      current_benefit_period = HbxProfile.current_hbx.benefit_sponsorship.current_benefit_coverage_period
      query = {
          :effective_on.lt => current_benefit_period.start_on,
          :kind => 'individual',
          :aasm_state.in => HbxEnrollment::ENROLLED_STATUSES - ['coverage_termination_pending', 'enrolled_contingent', 'unverified']
      }
      families = Family.where("households.hbx_enrollments" => {:$elemMatch => query})
      families.each do |family|
        begin
          family.active_household.hbx_enrollments.where(query).each do |enrollment|
            enrollment.expire_coverage! if enrollment.may_expire_coverage?
          end
        rescue Exception => e
          Rails.logger.error "Unable to expire enrollments for family #{family.e_case_id}"
        end
      end
    end

    def begin_coverage_for_ivl_enrollments
      current_benefit_period = HbxProfile.current_hbx.benefit_sponsorship.current_benefit_coverage_period
      query = {
          :effective_on => current_benefit_period.start_on,
          :kind => 'individual',
          :aasm_state => 'auto_renewing'
        }
      families = Family.where("households.hbx_enrollments" => {:$elemMatch => query})

      families.each do |family|
        family.active_household.hbx_enrollments.where(query).each do |enrollment|
          enrollment.begin_coverage! if enrollment.may_begin_coverage?
        end
      end
    end

    # Manage: SEPs, FamilyMemberAgeOff
    def advance_day(new_date)
      expire_individual_market_enrollments
      begin_coverage_for_ivl_enrollments
      send_enrollment_notice_for_ivl(new_date)
    end

    def send_enrollment_notice_for_ivl(new_date)
      start_time = (new_date - 2.days).in_time_zone("Eastern Time (US & Canada)").beginning_of_day
      end_time = (new_date - 2.days).in_time_zone("Eastern Time (US & Canada)").end_of_day
      families = Family.where({
        "households.hbx_enrollments" => {
          "$elemMatch" => {
            "kind" => "individual",
            "aasm_state" => { "$in" => HbxEnrollment::ENROLLED_STATUSES },
            "created_at" => { "$gte" => start_time, "$lte" => end_time},
        } }
      })
      families.each do |family|
        begin
          person = family.primary_applicant.person
          IvlNoticesNotifierJob.perform_later(person.id.to_s, "enrollment_notice") if person.consumer_role.present?
        rescue Exception => e
          Rails.logger.error { "Unable to deliver enrollment notice #{person.hbx_id} due to #{e.inspect}" }
        end
      end
    end

    def find_by_employee_role(employee_role)
      find_all_by_primary_applicant(employee_role.person).first
    end

    def find_or_build_from_employee_role(new_employee_role)
      existing_family = Family.find_by_employee_role(new_employee_role)

      if existing_family.present?
        existing_family
      else
        family = Family.new
        family.build_from_employee_role(new_employee_role)

        family.save!
        family
      end
    end

    def find_all_by_person(person)
      where("family_members.person_id" => person.id)
    end

    def find_primary_applicant_by_person(person)
      find_all_by_person(person).select() { |f| f.primary_applicant.person.id.to_s == person.id.to_s }
    end

    # @deprecated Use find_primary_applicant_by_person
    alias_method :find_all_by_primary_applicant, :find_primary_applicant_by_person

    # @deprecated Use find_primary_applicant_by_person
    alias_method :find_by_primary_family_member, :find_primary_applicant_by_person

    # @deprecated Use find_primary_applicant_by_person
    alias_method :find_by_primary_applicant, :find_primary_applicant_by_person

    def find_by_case_id(id)
      where({"e_case_id" => id}).to_a
    end
  end

  def build_consumer_role(family_member, opts = {})
    person = family_member.person
    return if person.consumer_role.present?
    person.build_consumer_role({:is_applicant => false}.merge(opts))
    person.save!
  end

  def check_for_consumer_role
    if primary_applicant.person.consumer_role.present?
      active_family_members.each do |family_member|
        build_consumer_role(family_member)
      end
    end
  end

  def build_resident_role(family_member, opts = {})
    person = family_member.person
    return if person.resident_role.present?
    person.build_resident_role({:is_applicant => false}.merge(opts))
    person.save!
  end

  def check_for_resident_role
    if primary_applicant.person.resident_role.present?
      active_family_members.each do |family_member|
        build_resident_role(family_member)
      end
    end
  end

  def has_aptc_hbx_enrollment?
    enrollments = latest_household.hbx_enrollments.active rescue []
    enrollments.any? {|enrollment| enrollment.applied_aptc_amount > 0}
  end

  def self.by_special_enrollment_period_id(special_enrollment_period_id)
    Family.where("special_enrollment_periods._id" => special_enrollment_period_id)
  end

  def all_enrollments
    if self.active_household.present?
      active_household.hbx_enrollments
    end
  end

  def enrolled_hbx_enrollments
    latest_household.try(:enrolled_hbx_enrollments)
  end

  def enrolled_including_waived_hbx_enrollments
    latest_household.try(:enrolled_including_waived_hbx_enrollments)
  end

  def enrollments_for_display
    Family.collection.aggregate([
      {"$match" => {'_id' => self._id}},
      {"$unwind" => '$households'},
      {"$unwind" => '$households.hbx_enrollments'},
      {"$match" => {"households.hbx_enrollments.aasm_state" => {"$nin" => ['void', "coverage_canceled"]} }},
      {"$match" => {"households.hbx_enrollments.external_enrollment" => {"$ne" => true}}},
      {"$sort" => {"households.hbx_enrollments.submitted_at" => -1 }},
      {"$group" => {'_id' => {
                  'year' => { "$year" => '$households.hbx_enrollments.effective_on'},
                  'month' => { "$month" => '$households.hbx_enrollments.effective_on'},
                  'day' => { "$dayOfMonth" => '$households.hbx_enrollments.effective_on'},
                  'subscriber_id' => '$households.hbx_enrollments.enrollment_signature',
                  'provider_id'   => '$households.hbx_enrollments.carrier_profile_id',
                  'benefit_group_id' => '$households.hbx_enrollments.benefit_group_id',
                  'state' => '$households.hbx_enrollments.aasm_state',
                  'market' => '$households.hbx_enrollments.kind',
                  'coverage_kind' => '$households.hbx_enrollments.coverage_kind'},
                  "hbx_enrollment" => { "$first" => '$households.hbx_enrollments'}}},
      {"$project" => {'hbx_enrollment._id' => 1, '_id' => 1}}
      ],
      :allow_disk_use => true)
  end

  def waivers_for_display
    Family.collection.aggregate([
      {"$match" => {'_id' => self._id}},
      {"$unwind" => '$households'},
      {"$unwind" => '$households.hbx_enrollments'},
      {"$match" => {'households.hbx_enrollments.aasm_state' => 'inactive'}},
      {"$sort" => {"households.hbx_enrollments.submitted_at" => -1 }},
      {"$group" => {'_id' => {'year' => { "$year" => '$households.hbx_enrollments.effective_on'},
                    'state' => '$households.hbx_enrollments.aasm_state',
                    'kind' => '$households.hbx_enrollments.kind',
                    'coverage_kind' => '$households.hbx_enrollments.coverage_kind'}, "hbx_enrollment" => { "$first" => '$households.hbx_enrollments'}}},
      {"$project" => {'hbx_enrollment._id' => 1, '_id' => 0}}
      ],
      :allow_disk_use => true)
  end

  def generate_family_search
    ::MapReduce::FamilySearchForFamily.populate_for(self)
  end

  def create_dep_consumer_role
    if dependents.any?
      dependents.each do |member|
        build_consumer_role(member)
      end
    end
  end

  def best_verification_due_date
    due_date = contingent_enrolled_family_members_due_dates.detect do |date|
      date > TimeKeeper.date_of_record && (date.to_date.mjd - TimeKeeper.date_of_record.mjd) >= 30
    end
    due_date || contingent_enrolled_family_members_due_dates.last
  end

  def contingent_enrolled_family_members_due_dates
    due_dates = []
    contingent_enrolled_active_family_members.each do |family_member|
      family_member.person.verification_types.each do |v_type|
        due_dates << document_due_date(family_member, v_type)
      end
    end
    due_dates.compact!
    due_dates.uniq.sort
  end

  def min_verification_due_date_on_family
    contingent_enrolled_family_members_due_dates.min.to_date if contingent_enrolled_family_members_due_dates.present?
  end

  def contingent_enrolled_active_family_members
    enrolled_family_members = []
    family_members.active.each do |family_member|
      if enrolled_policy(family_member).present?
        enrolled_family_members << family_member
      end
    end
    enrolled_family_members
  end

  def document_due_date(family_member, v_type)
    return nil if family_member.person.consumer_role.is_type_verified?(v_type)
    sv = family_member.person.consumer_role.special_verifications.where(verification_type: v_type).order_by(:"created_at".desc).first
    sv.present? ? sv.due_date : nil
  end

  def enrolled_policy(family_member)
    enrollments.verification_needed.where(:"hbx_enrollment_members.applicant_id" => family_member.id).first
  end

  def review_status
    if active_household.hbx_enrollments.verification_needed.any?
      active_household.hbx_enrollments.verification_needed.first.review_status
    else
      "no enrollment"
    end
  end

  def person_has_an_active_enrollment?(person)
    active_household.hbx_enrollments.where(:aasm_state.in => HbxEnrollment::ENROLLED_STATUSES).flat_map(&:hbx_enrollment_members).flat_map(&:family_member).flat_map(&:person).include?(person)
  end

  def self.min_verification_due_date_range(start_date,end_date)
    timekeeper_date = TimeKeeper.date_of_record + 95.days
    if timekeeper_date >= start_date.to_date && timekeeper_date <= end_date.to_date
      self.or(:"min_verification_due_date" => { :"$gte" => start_date, :"$lte" => end_date}).or(:"min_verification_due_date" => nil)
    else
     self.or(:"min_verification_due_date" => { :"$gte" => start_date, :"$lte" => end_date})
    end
  end

  def all_persons_vlp_documents_status
    documents_list = []
    document_status_outstanding = []
    self.active_family_members.each do |member|
      member.person.verification_types.each do |type|
      if member.person.consumer_role && is_document_not_verified(type, member.person)
        documents_list <<  (member.person.consumer_role.has_docs_for_type?(type) && verification_type_status(type, member.person) != "outstanding")
        document_status_outstanding << member.person.consumer_role.has_outstanding_documents?
      end
      end
    end
    case
    when documents_list.include?(true) && documents_list.include?(false)
      return "Partially Uploaded"
    when documents_list.include?(true) && !documents_list.include?(false)
      if document_status_outstanding.include?("outstanding")
        return "Partially Uploaded"
      else
        return "Fully Uploaded"
      end
    when !documents_list.include?(true) && documents_list.include?(false)
      return "None"
    end
  end

  def update_family_document_status!
    update_attributes(vlp_documents_status: self.all_persons_vlp_documents_status)
  end

  def is_document_not_verified(type, person)
    ["valid", "attested", "verified", "External Source"].include?(verification_type_status(type, person))?  false : true
  end

  def has_valid_e_case_id?
    return false if !e_case_id
    e_case_id.split('#').last.scan(/\D/).empty?
  end

private
  def build_household
    if households.size == 0
      initialize_household
    end
  end

  def family_integrity
    only_one_active_primary_family
    single_primary_family_member
    all_family_member_relations_defined
    single_active_household
    no_duplicate_family_members
  end

  def primary_applicant_person
    return nil unless primary_applicant.present?
    primary_applicant.person
  end

  def only_one_active_primary_family
    return unless primary_family_member.present? && primary_family_member.person.present?
    families_with_same_primary = Family.where(
      "family_members" => {
        "$elemMatch" => {
          "is_primary_applicant" => true,
          "person_id" => BSON::ObjectId.from_string(primary_family_member.person_id.to_s)
        }
      },
      "is_active" => true
    )
    if (families_with_same_primary.any? { |fam| fam.id.to_s != self.id.to_s })
      self.errors.add(:base, "has another active family with the same primary applicant")
    end
  end

  def single_primary_family_member
    list = family_members.reduce([]) { |list, family_member| list << family_member if family_member.is_primary_applicant?; list }
    self.errors.add(:family_members, "one family member must be primary family member") if list.size == 0
    self.errors.add(:family_members, "may not have more than one primary family member") if list.size > 1
  end

  def all_family_member_relations_defined
    return unless primary_family_member.present? && primary_family_member.person.present?
    primary_member_id = primary_family_member.id
    primary_person = primary_family_member.person
    other_family_members = family_members.select { |fm| (fm.id.to_s != primary_member_id.to_s) && fm.person.present? }
    undefined_relations = other_family_members.any? { |fm| primary_person.find_relationship_with(fm.person).blank? }
    errors.add(:family_members, "relationships between primary_family_member and all family_members must be defined") if undefined_relations
  end

  def single_active_household
    list = households.reduce([]) { |list, household| list << household if household.is_active?; list }
    self.errors.add(:households, "one household must be active") if list.size == 0
    self.errors.add(:households, "may not have more than one active household") if list.size > 1
  end

  def initialize_household
    households.build(submitted_at: DateTime.current)
  end

  def no_duplicate_family_members
    family_members.group_by { |appl| appl.person_id }.select { |k, v| v.size > 1 }.each_pair do |k, v|
      errors.add(:family_members, "Duplicate family_members for person: #{k}\n" +
                          "family_members: #{v.inspect}")
    end
  end


  def are_arrays_of_family_members_same?(base_set, test_set)
    base_set.uniq.sort == test_set.uniq.sort
  end

  def reset_active_household(new_household)
    households.each do |household|
      household.is_active = false
    end
    new_household.is_active = true
  end

  def valid_relationship?(family_member)
    return true if primary_applicant.nil? #responsible party case
    return true if primary_applicant.person.id == family_member.person.id

    if IMMEDIATE_FAMILY.include? primary_applicant.person.find_relationship_with(family_member.person)
      return true
    else
      return false
    end
  end

  def clear_blank_fields
    if e_case_id.blank?
      unset("e_case_id")
    end
  end
end
