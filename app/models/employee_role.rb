class EmployeeRole
  include Mongoid::Document
  include SetCurrentUser
  include Mongoid::Timestamps
  include Acapi::Notifiers
  include ModelEvents::EmployeeRole
  include Concerns::Observable

  EMPLOYMENT_STATUS_KINDS   = ["active", "full-time", "part-time", "retired", "terminated"]

  embedded_in :person

  field :employer_profile_id, type: BSON::ObjectId
  field :census_employee_id, type: BSON::ObjectId
  field :benefit_group_id, type: BSON::ObjectId  # TODO: Deprecate
  field :employment_status, type: String
  field :hired_on, type: Date
  field :terminated_on, type: Date
  field :is_active, type: Boolean, default: true
  field :bookmark_url, type: String, default: nil
  field :contact_method, type: String, default: "Paper and Electronic communications"
  field :language_preference, type: String, default: "English"
  delegate :hbx_id, to: :person, allow_nil: true
  delegate :ssn, :ssn=, to: :person, allow_nil: true
  delegate :dob, :dob=, to: :person, allow_nil: true
  delegate :gender, :gender=, to: :person, allow_nil: true

  validates_presence_of :dob, :gender, :employer_profile_id, :hired_on
  scope :active, ->{ where(is_active: true).where(:created_at.ne => nil) }

  accepts_nested_attributes_for :person

  before_save :termination_date_must_follow_hire_date

  after_create :notify_on_create

  # hacky fix for nested attributes
  # TODO: remove this when it is no longer needed
  after_initialize do |employee_role|
    if employee_role.person.present?
      @changed_nested_person_attributes = {}
      %w[ssn dob gender hbx_id].each do |field|
        if employee_role.person.send("#{field}_changed?")
          @changed_nested_person_attributes[field] = employee_role.person.send(field)
        end
      end
    end
    true
  end
  after_build do |employee_role|
    if employee_role.person.present? && @changed_nested_person_attributes.present?
      employee_role.person.update_attributes(@changed_nested_person_attributes)
      unset @changed_nested_person_attributes
    end
    true
  end


  ## TODO: propogate to EmployerCensus updates to employee demographics and family

  def families
    Family.find_by_employee_role(self)
  end

  # belongs_to Employer
  def employer_profile=(new_employer)
    raise ArgumentError.new("expected EmployerProfile") unless new_employer.is_a? EmployerProfile
    self.employer_profile_id = new_employer._id
    @employer_profile = new_employer
  end

  def employer_profile
    return @employer_profile if defined? @employer_profile
    @employer_profile = EmployerProfile.find(self.employer_profile_id)
  end

  def benefit_group(qle: false)
    if qle && active_coverage_benefit_group
      active_coverage_benefit_group
    elsif qle && renewal_coverage
      census_employee.renewal_published_benefit_group
    else
      census_employee.renewal_published_benefit_group || census_employee.published_benefit_group
    end
  end

  def active_coverage_benefit_group
    expired_plan_year = self.employer_profile.plan_years.where(aasm_state: "expired").order_by(:'start_on'.desc).first
    if expired_plan_year.present?
      bg_list = expired_plan_year.benefit_groups.map(&:id)
      bg = self.census_employee.benefit_group_assignments.where(:benefit_group_id.in => bg_list).order_by(:'created_at'.desc).first.try(:benefit_group)
      effective_on = person.primary_family.current_sep.effective_on
      return bg if bg.present? && bg.start_on <= effective_on &&  bg.end_on >= effective_on
    end
    bg = census_employee.active_benefit_group
    effective_on = person.primary_family.current_sep.effective_on
    return bg if bg.start_on <= effective_on &&  bg.end_on >= effective_on
  end

  def renewal_coverage
    bg = census_employee.renewal_published_benefit_group
    effective_on = person.primary_family.current_sep.effective_on
    bg.start_on <= effective_on &&  bg.end_on >= effective_on if bg.present?
  end

  def is_under_open_enrollment?
    employer_profile.show_plan_year.present? && employer_profile.show_plan_year.open_enrollment_contains?(TimeKeeper.date_of_record)
  end

  def is_eligible_to_enroll_without_qle?
    is_under_open_enrollment? || census_employee.new_hire_enrollment_period.cover?(TimeKeeper.date_of_record) || census_employee.new_hire_enrollment_period.min > TimeKeeper.date_of_record
  end

  def new_census_employee=(new_census_employee)
    raise ArgumentError.new("expected CensusEmployee class") unless new_census_employee.is_a? CensusEmployee
    self.census_employee_id = new_census_employee._id
    @census_employee = new_census_employee
  end

  def new_census_employee
    return @census_employee if defined? @census_employee
    @census_employee = CensusMember.find(self.census_employee_id) unless census_employee_id.blank?
  end

  alias_method :census_employee=, :new_census_employee=
  alias_method :census_employee, :new_census_employee

  def is_cobra_status?
    if census_employee.present?
      census_employee.is_cobra_status?
    else
      false
    end
  end

  def coverage_effective_on(current_benefit_group: nil, qle: false)
    if qle && benefit_group(qle: qle).present?
      current_benefit_group = benefit_group(qle: qle)
    end

    census_employee.coverage_effective_on(current_benefit_group)
  end

  def can_enroll_as_new_hire?
    census_employee.new_hire_enrollment_period.cover?(TimeKeeper.date_of_record)
  end

  def is_active?
    census_employee && census_employee.is_active?
  end

  def can_select_coverage?
    hired_on + 60.days >= TimeKeeper.date_of_record
  end

  def is_dental_offered?
    plan_year = employer_profile.find_plan_year_by_effective_date(coverage_effective_on(current_benefit_group: benefit_group))

    benefit_group_assignments = [census_employee.renewal_benefit_group_assignment, census_employee.active_benefit_group_assignment].compact
    benefit_group_assignment  = benefit_group_assignments.detect{|bpkg| bpkg.plan_year == plan_year}
    benefit_group_assignment.present? && benefit_group_assignment.benefit_group.is_offering_dental? ? true : false
  end

  class << self
    def klass
      self.to_s.underscore
    end

    def find(employee_role_id)
      bson_id = BSON::ObjectId.from_string(employee_role_id)
      person = Person.where({"employee_roles._id" => bson_id })
      person.first.employee_roles.detect { |ee| ee.id == bson_id } unless person.size < 1
    end

    def find_by_employer_profile(employer_profile)
      Person.where("employee_roles.employer_profile_id" => employer_profile.id).reduce([]) do |list, person|
        list << person.employee_roles.detect { |ee| ee.employer_profile_id == employer_profile.id }
      end
    end

    def ids_in(collection)
      list Person.in("employee_roles._id" => collection)
    end

    def list(collection)
      collection.reduce([]) { |elements, person| elements.concat person.send(klass.pluralize) }
    end

    # TODO: return as chainable Mongoid::Criteria
    def all
      # criteria = Mongoid::Criteria.new(Person)
      list Person.exists(klass.pluralize.to_sym => true)
    end

    def first
      self.all.first
    end
  end

private

  def termination_date_must_follow_hire_date
    return if hired_on.nil? || terminated_on.nil?
    errors.add(:terminated_on, "terminated_on cannot preceed hired_on") if terminated_on < hired_on
  end
end
