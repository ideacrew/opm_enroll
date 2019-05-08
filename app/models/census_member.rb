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
  scope :non_business_owner,              ->{ where(is_business_owner: false) }
  scope :eligible_without_term_pending, ->{ any_in(aasm_state: (ELIGIBLE_STATES - PENDING_STATES)) }


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
