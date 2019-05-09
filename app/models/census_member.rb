class CensusMember
  include Mongoid::Document
  include Mongoid::Timestamps
  include UnsetableSparseFields
  validates_with Validations::DateRangeValidator

  GENDER_KINDS = %W(male female)
  EMPLOYMENT_ACTIVE_STATES = %w(eligible employee_role_linked employee_termination_pending newly_designated_eligible newly_designated_linked cobra_eligible cobra_linked cobra_termination_pending)
  EMPLOYMENT_TERMINATED_STATES = %w(employment_terminated rehired cobra_terminated)
  NEWLY_DESIGNATED_STATES = %w(newly_designated_eligible newly_designated_linked)
  LINKED_STATES = %w(employee_role_linked newly_designated_linked cobra_linked)
  ELIGIBLE_STATES = %w(eligible newly_designated_eligible cobra_eligible employee_termination_pending cobra_termination_pending)
  COBRA_STATES = %w(cobra_eligible cobra_linked cobra_terminated cobra_termination_pending)
  PENDING_STATES = %w(employee_termination_pending cobra_termination_pending)

  EMPLOYEE_TERMINATED_EVENT_NAME = "acapi.info.events.census_employee.terminated"
  EMPLOYEE_COBRA_TERMINATED_EVENT_NAME = "acapi.info.events.census_employee.cobra_terminated"

  field :first_name, type: String
  field :middle_name, type: String
  field :last_name, type: String
  field :name_sfx, type: String

  include StrippedNames

  field :encrypted_ssn, type: String
  field :dob, type: Date
  field :gender, type: String

  field :employee_relationship, type: String
  field :employer_assigned_family_id, type: String

  embeds_one :address
  accepts_nested_attributes_for :address, reject_if: :all_blank, allow_destroy: true

  embeds_one :email
  accepts_nested_attributes_for :email, allow_destroy: true

  validates_presence_of :first_name, :last_name, :dob, :employee_relationship

  validates :gender,
    allow_blank: false,
    inclusion: { in: GENDER_KINDS, message: "must be selected" }

  # validates :ssn,
  #   length: { minimum: 9, maximum: 9, message: "SSN must be 9 digits" },
  #   allow_blank: true,
  #   numericality: true


  validate :date_of_birth_is_past


  scope :active,            ->{ any_in(aasm_state: EMPLOYMENT_ACTIVE_STATES) }
  scope :terminated,        ->{ any_in(aasm_state: EMPLOYMENT_TERMINATED_STATES) }
  scope :non_terminated,    ->{ where(:aasm_state.nin => EMPLOYMENT_TERMINATED_STATES) }
  scope :newly_designated,  ->{ any_in(aasm_state: NEWLY_DESIGNATED_STATES) }
  scope :linked,            ->{ any_in(aasm_state: LINKED_STATES) }
  scope :eligible,          ->{ any_in(aasm_state: ELIGIBLE_STATES) }
  scope :without_cobra,     ->{ not_in(aasm_state: COBRA_STATES) }
  scope :by_cobra,          ->{ any_in(aasm_state: COBRA_STATES) }
  scope :pending,           ->{ any_in(aasm_state: PENDING_STATES) }
  scope :eligible_without_term_pending, ->{ any_in(aasm_state: (ELIGIBLE_STATES - PENDING_STATES)) }

  #TODO - need to add fix for multiple plan years
  # scope :enrolled,    ->{ where("benefit_group_assignments.aasm_state" => ["coverage_selected", "coverage_waived"]) }
  # scope :covered,     ->{ where( "benefit_group_assignments.aasm_state" => "coverage_selected" ) }
  # scope :waived,      ->{ where( "benefit_group_assignments.aasm_state" => "coverage_waived" ) }

  scope :covered,    ->{ where(:"benefit_group_assignments" => {
    :$elemMatch => { :aasm_state => "coverage_selected", :is_active => true }
    })}

  scope :waived,    ->{ where(:"benefit_group_assignments" => {
    :$elemMatch => { :aasm_state => "coverage_waived", :is_active => true }
    })}

  scope :enrolled, -> { any_of([covered.selector, waived.selector]) }


  scope :employee_name, -> (employee_name) { any_of({first_name: /#{employee_name}/i}, {last_name: /#{employee_name}/i}, first_name: /#{employee_name.split[0]}/i, last_name: /#{employee_name.split[1]}/i) }

  scope :sorted,                -> { order(:"census_employee.last_name".asc, :"census_employee.first_name".asc)}
  scope :order_by_last_name,    -> { order(:"census_employee.last_name".asc) }
  scope :order_by_first_name,   -> { order(:"census_employee.first_name".asc) }

  scope :by_employer_profile_id,          ->(employer_profile_id) { where(employer_profile_id: employer_profile_id) }
  scope :non_business_owner,              ->{ where(is_business_owner: false) }
  scope :by_benefit_group_assignment_ids, ->(benefit_group_assignment_ids) { any_in("benefit_group_assignments._id" => benefit_group_assignment_ids) }
  scope :by_benefit_group_ids,            ->(benefit_group_ids) { any_in("benefit_group_assignments.benefit_group_id" => benefit_group_ids) }
  scope :by_ssn,                          ->(ssn) { where(encrypted_ssn: CensusMember.encrypt_ssn(ssn)).and(:encrypted_ssn.nin => ["", nil]) }
  scope :search_with_ssn_dob,              ->(ssn, dob) { unscoped.where(encrypted_ssn: CensusMember.encrypt_ssn(ssn), dob: dob) }
  scope :search_dependent_with_ssn_dob,    ->(ssn, dob) { unscoped.where(:"census_dependents.encrypted_ssn" => CensusMember.encrypt_ssn(ssn), :"census_dependents.dob" => dob) }

  scope :matchable, ->(ssn, dob) {
    matched = unscoped.and(encrypted_ssn: CensusMember.encrypt_ssn(ssn), dob: dob, aasm_state: {"$in": ELIGIBLE_STATES })
    benefit_group_assignment_ids = matched.flat_map() do |ee|
      ee.published_benefit_group_assignment ? ee.published_benefit_group_assignment.id : []
    end
    matched.by_benefit_group_assignment_ids(benefit_group_assignment_ids)
  }

  scope :unclaimed_matchable, ->(ssn, dob) {
   linked_matched = unscoped.and(encrypted_ssn: CensusMember.encrypt_ssn(ssn), dob: dob, aasm_state: {"$in": LINKED_STATES})
   unclaimed_person = Person.where(encrypted_ssn: CensusMember.encrypt_ssn(ssn), dob: dob).detect{|person| person.employee_roles.length>0 && !person.user }
   unclaimed_person ? linked_matched : unscoped.and(id: {:$exists => false})
  }

  scope :matchable_by_dob_lname_fname, ->(dob, first_name, last_name) {
    matched = unscoped.and(dob: dob, first_name: first_name, last_name: last_name, aasm_state: {"$in": ELIGIBLE_STATES })
    benefit_group_assignment_ids = matched.flat_map() do |ee|
      ee.published_benefit_group_assignment ? ee.published_benefit_group_assignment.id : []
    end
    matched.by_benefit_group_assignment_ids(benefit_group_assignment_ids)
  }







  # scope :active,            ->{ any_in(aasm_state: EMPLOYMENT_ACTIVE_STATES) }
  # scope :non_business_owner,              ->{ where(is_business_owner: false) }
  # scope :eligible_without_term_pending, ->{ any_in(aasm_state: (ELIGIBLE_STATES - PENDING_STATES)) }
  # scope :by_benefit_group_ids,            ->(benefit_group_ids) { any_in("benefit_group_assignments.benefit_group_id" => benefit_group_ids) }


  after_validation :move_encrypted_ssn_errors

  def move_encrypted_ssn_errors
    deleted_messages = errors.delete(:encrypted_ssn)
    if !deleted_messages.blank?
      deleted_messages.each do |dm|
        errors.add(:ssn, dm)
      end
    end
    true
  end

  def active_benefit_group_assignment
    benefit_group_assignments.detect { |assignment| assignment.is_active? }
  end
  
  def self.search_hash(s_rex)
    clean_str = s_rex.strip.split.map{|i| Regexp.escape(i)}.join("|")
    action = s_rex.strip.split.size > 1 ? "$and" : "$or"
    search_rex = Regexp.compile(clean_str, true)
    {
        "$or" => [
            {action => [
                {"first_name" => search_rex},
                {"last_name" => search_rex}
            ]},
            {"encrypted_ssn" => encrypt_ssn(clean_str)}
        ]
    }
end

  def self.find_all_by_benefit_group(benefit_group)
    unscoped.where("benefit_group_assignments.benefit_group_id" => benefit_group._id)
  end

  def ssn_changed?
    encrypted_ssn_changed?
  end

  def self.encrypt_ssn(val)
    if val.blank?
      return nil
    end
    ssn_val = val.to_s.gsub(/\D/, '')
    SymmetricEncryption.encrypt(ssn_val)
  end

  def self.decrypt_ssn(val)
    SymmetricEncryption.decrypt(val)
  end

  # Strip non-numeric chars from ssn
  # SSN validation rules, see: http://www.ssa.gov/employer/randomizationfaqs.html#a0=12
  def ssn=(new_ssn)
    if !new_ssn.blank?
      write_attribute(:encrypted_ssn, CensusMember.encrypt_ssn(new_ssn))
    else
      unset_sparse("encrypted_ssn")
    end
  end

  def ssn
    ssn_val = read_attribute(:encrypted_ssn)
    if !ssn_val.blank?
      CensusMember.decrypt_ssn(ssn_val)
    else
      nil
    end
  end

  def gender=(val)
    if val.blank?
      write_attribute(:gender, nil)
      return
    end
    write_attribute(:gender, val.downcase)
  end

  def dob_string
    self.dob.blank? ? "" : self.dob.strftime("%Y%m%d")
  end

  def date_of_birth
    self.dob.blank? ? nil : self.dob.strftime("%m/%d/%Y")
  end

  def date_of_birth=(val)
    self.dob = Date.strptime(val, "%Y-%m-%d").to_date rescue nil
  end

  def full_name
    [first_name, middle_name, last_name, name_sfx].compact.join(" ")
  end

  def date_of_birth_is_past
    return unless self.dob.present?
    errors.add(:dob, "future date: #{self.dob} is invalid date of birth") if TimeKeeper.date_of_record < self.dob
  end

  def age_on(date)
    age = date.year - dob.year
    if date.month == dob.month
      age -= 1 if date.day < dob.day
    else
      age -= 1 if date.month < dob.month
    end
    age
  end
end
