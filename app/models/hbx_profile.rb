class HbxProfile
  include Config::AcaModelConcern
  include Config::SiteModelConcern
  include Config::ContactCenterModelConcern
  include Mongoid::Document
  include SetCurrentUser
  include Mongoid::Timestamps
  extend Acapi::Notifiers

  embedded_in :organization

  field :cms_id, type: String
  field :us_state_abbreviation, type: String

  delegate :legal_name, :legal_name=, to: :organization, allow_nil: true
  delegate :dba, :dba=, to: :organization, allow_nil: true
  delegate :fein, :fein=, to: :organization, allow_nil: true
  delegate :entity_kind, :entity_kind=, to: :organization, allow_nil: true

  embeds_many :hbx_staff_roles
  embeds_many :enrollment_periods # TODO: deprecated - should be removed by 2015-09-03 - Sean Carley

  embeds_one :benefit_sponsorship, cascade_callbacks: true
  embeds_one :inbox, as: :recipient, cascade_callbacks: true

  accepts_nested_attributes_for :inbox, :benefit_sponsorship

  validates_presence_of :us_state_abbreviation, :cms_id

  after_initialize :build_nested_models

  def advance_day
  end

  def advance_month
  end

  def advance_quarter
  end

  def advance_year
  end

  def under_open_enrollment?
    (benefit_sponsorship.present? && benefit_sponsorship.is_coverage_period_under_open_enrollment?) ?  true : false
  end

  def active_employers
    EmployerProfile.active
  end

  def inactive_employers
    EmployerProfile.inactive
  end

  def active_employees
    CensusEmployee.active
  end

  def active_broker_agencies
    BrokerAgencyProfile.active
  end

  def inactive_broker_agencies
    BrokerAgencyProfile.inactive
  end

  def active_brokers
    BrokerRole.active
  end

  def inactive_brokers
    BrokerRole.inactive
  end


  class << self
    def find(id)
      org = Organization.where("hbx_profile._id" => BSON::ObjectId.from_string(id)).first
      org.hbx_profile if org.present?
    end

    def find_by_cms_id(id)
      org = Organization.where("hbx_profile.cms_id": id).first
      org.hbx_profile if org.present?
    end

    def find_by_state_abbreviation(state)
      org = Organization.where("hbx_profile.us_state_abbreviation": state.to_s.upcase).first
      org.hbx_profile if org.present?
    end

    def all
      Organization.exists(hbx_profile: true).all.reduce([]) { |set, org| set << org.hbx_profile }
    end

    def current_hbx
      find_by_state_abbreviation(aca_state_abbreviation)
    end

    def transmit_group_xml(employer_profile_ids)
      hbx_ids = []
      employer_profile_ids.each do |empr_id|
        empr = EmployerProfile.find(empr_id)
        hbx_ids << empr.hbx_id
        empr.update_attribute(:xml_transmitted_timestamp, Time.now.utc)
      end
      notify("acapi.info.events.employer.group_files_requested", { body: hbx_ids } )
    end

    def search_random(search_param)
      if search_param.present?
        organizations = Organization.where(legal_name: /#{search_param}/i)
        broker_agency_profiles = []
        organizations.each do |org|
          broker_agency_profiles << org.broker_agency_profile if org.broker_agency_profile.present?
        end
      else
        broker_agency_profiles = BrokerAgencyProfile.all
      end
      broker_agency_profiles
    end
  end

  ## Application-level caching

  ## HBX general settings
  StateName = aca_state_name
  StateAbbreviation = aca_state_abbreviation
  CallCenterName = contact_center_name
  CallCenterPhoneNumber = contact_center_phone_number
  ShortName = site_short_name

  IndividualEnrollmentDueDayOfMonth = 15

  #New Rule There is no 14 days rule for termination
  # IndividualEnrollmentTerminationMinimum = 14.days

  ## Carriers
  # hbx_id, hbx_carrier_id, name, abbrev,

  ## Plans & Premiums
  # hbx_id, hbx_plan_id, hbx_carrier_id, hios_id, year, quarter, name, abbrev, market, type, metal_level, pdf

  ## Cross-reference ID Directory
  # Person
  # Employer
  # BrokerAgency
  # Policy

  ## HBX Policies for IVL Market
  # Open Enrollment periods

  ## SHOP Market HBX Policies
  # Employer Contribution Strategies

  # New hires in initial group that start after enrollment, but prior to coverage effective date.  Don't
  # transmit EDI prior to Employer coverage effective date


  # Maximum number of days an Employer may notify HBX of termination
  # may terminate an employee and effective date
  # ShopRetroactiveTerminationMaximum = 60.days
  #
  # # Length of time preceeding next effective date that an employer may renew
  # ShopMaximumRenewalPeriodBeforeStartOn = 3.months
  #
  # # Length of time preceeding effective date that an employee may submit a plan enrollment
  # ShopMaximumEnrollmentPeriodBeforeEligibilityInDays = 30
  #
  # # Length of time following effective date that an employee may submit a plan enrollment
  # ShopMaximumEnrollmentPeriodAfterEligibilityInDays = 30
  #
  # # Minimum number of days an employee may submit a plan, following addition or correction to Employer roster
  # ShopMinimumEnrollmentPeriodAfterRosterEntryInDays = 30
  #
  # # TODO - turn into struct that includes count, plus effective date range
  # ShopApplicationAppealPeriodMaximum = 30.days
  #
  # # After submitting an ineligible plan year application, time period an Employer must wait
  # #   before submitting a new application
  # ShopApplicationIneligiblePeriodMaximum = 90.days
  #
  # # TODO - turn into struct that includes count, plus effective date range
  # ShopSmallMarketFteCountMaximum = 50
  #
  # ## SHOP enrollment-related periods in days
  # # Minimum number of days for SHOP open enrollment period
  # ShopOpenEnrollmentPeriodMinimum = 5
  # ShopOpenEnrollmentEndDueDayOfMonth = 10
  #
  # # Maximum number of months for SHOP open enrollment period
  # ShopOpenEnrollmentPeriodMaximum = 2
  #
  # # Minumum length of time for SHOP Plan Year
  # ShopPlanYearPeriodMinimum = 1.year - 1.day
  #
  # # Maximum length of time for SHOP Plan Year
  # ShopPlanYearPeriodMaximum = 1.year - 1.day
  #
  # # Maximum number of months prior to coverage effective date to submit a Plan Year application
  # ShopPlanYearPublishBeforeEffectiveDateMaximum = 3.months
  #
  # ShopEmployerContributionPercentMinimum = 50.0
  # ShopEnrollmentParticipationRatioMinimum = 2 / 3.0
  # ShopEnrollmentNonOwnerParticipationMinimum = 1
  #
  # ShopBinderPaymentDueDayOfMonth = 15
  # ShopRenewalOpenEnrollmentEndDueDayOfMonth = 13


  ShopOpenEnrollmentBeginDueDayOfMonth = Settings.aca.shop_market.open_enrollment.monthly_end_on - Settings.aca.shop_market.open_enrollment.minimum_length.days
  ShopPlanYearPublishedDueDayOfMonth = ShopOpenEnrollmentBeginDueDayOfMonth
  ShopOpenEnrollmentAdvBeginDueDayOfMonth = Settings.aca.shop_market.open_enrollment.minimum_length.adv_days


  # ShopOpenEnrollmentStartMax
  # EffectiveDate

  # CoverageEffectiveDate - no greater than 3 calendar months max
  # ApplicationPublished latest date - 5th end_of_day  of preceding month

  # OpenEnrollment earliest start - 2 calendar months preceding CoverageEffectiveDate
  # OpenEnrollment min length - 5 days
  # OpenEnrollment latest start date - 5th of month
  # OpenEnrollmentLatestEnd -- 10th day of month prior to effective date
  # BinderPaymentDueDate -- 15th or earliest banking day prior

  private
  def build_nested_models
    build_inbox if inbox.nil?
  end

  def save_inbox
    welcome_subject = "Welcome to #{site_short_name}"
    welcome_body = "#{site_short_name} is the #{aca_state_name}'s on-line marketplace to shop, compare, and select health insurance that meets your health needs and budgets."
    @inbox.save
    @inbox.messages.create(subject: welcome_subject, body: welcome_body)
  end
end



"Rice","Ann","08-02-1968","218003753","168245"
"Sullivan","Laura",03-30-2001,"564002222","168246"
"Evans","Antonio","01-16-2005","276001549","168247"
Hughes,Irene,01-05-1980,654005069,"176027"
Wood,Karen,09-22-1959,136006345,"18772833"
Ross,Sarah,02-25-1956,701005392,"18772834"
Russell,Sarah,10-02-1967,688003538,"18825992"
Russell,Sarah,10-02-1967,535005143,"19755086"
King,Janet,01-03-1998,622003512,"18828576"
King,Janet,04-03-1998,657001443,"19755088"
Gray,Elizabeth,01-09-2000,737003298,"18828575"
Gray,Elizabeth,10-09-2000,296005076,"19755091"
Alexander,Gloria,03-01-1977,748006109,"18839136"
Reid,Donald,06-14-1982,732006838,"18839137"
Berry,Rose,12-20-1964,523001174,"19746705"
Little,Carolyn,02-08-1993,134004625,"19746709"
Lane,Craig,07-01-1995,690004484,"19746710"
Sims,Ryan,07-03-1997,539001356,19746711
Owens,Tina,08-27-1954,188002525,19754881
Webb,Angela,12-03-1961,732001333,19754010
Greene,Jonathan,08-06-1965,106006732,19754015
Greene,Virginia,09-05-1981,376006688,19756609
Spencer,Barbara,11-30-1996,470006682,19776212
Perry,Justin,03-25-1960,247003486,19746065
Mitchell,Laura,08-25-1963,253006317,19972591
Richardson,Gloria,07-18-1997,637004458,19974272
Gray,Christine,08-02-1988,620002597,19985318
Payne,Jesse,01-13-1983,615002592,20034525
Day,Jose,11-06-1958,509003189,20035283
Lopez,John,01-20-1966,703003986,20035284
Carter,Lawrence,03-06-1999,193002864,20035285
Meyer,Melissa,02-12-2001,671003601,20035286
Gomez,Joshua,03-28-1979,413006292,20036596
Jackson,Ronald,04-04-1983,427002931,20042470
Murray,Janice,09-20-2019,574003600,20053686