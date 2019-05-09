  require 'mongo'
require 'csv'
require 'pp'
require 'securerandom'

class OpmSeed

  def initialize
    @ee_count = {}
    @age_codes = {
      "A" => young,
      "B" => twenty,
      "C" => twenty_five,
      "D" => thirty,
      "E" => thirty_five,
      "F" => forty,
      "G" => forty_five,
      "H" => fifty,
      "I" => fifty_five,
      "J" => sixty,
      "K" => sixty_five,
      'Z' => old }  
    @agency_codes = {}
    @ssn= "0000001"
    @ee_count_mapping = {}
    @eps = Organization.all.map(&:employer_profile).compact.map(&:id)
    @org_cache =  ActiveSupport::Cache::MemoryStore.new
    @people = []
    @families = []
    @ces = []
  
    # @client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'opm_development')
    @client = Mongo::Client.new([ '172.30.1.55:27017' ], :database => 'enroll_opm', auth_source: 'admin', user:'admin', password:'enrUAT7102*@!')
  end

  def time_rand from = 0.0, to = Time.now
    Time.at(from + rand * (to.to_f - from.to_f))
  end

  def young 
    time_rand (Time.now - 1.years ),(Time.now - 20.years)
  end

  def twenty 
    time_rand (Time.now - 20.years),(Time.now - 24.years)
  end

  def twenty_five
    time_rand (Time.now - 25.years),(Time.now - 29.years)
  end

  def thirty
    time_rand (Time.now - 30.years),(Time.now - 34.years)
  end

  def thirty_five
    time_rand (Time.now - 35.years),(Time.now - 39.years)
  end

  def forty
    time_rand (Time.now - 40.years),(Time.now - 44.years)
  end

  def forty_five
    time_rand (Time.now - 45.years),(Time.now - 49.years)
  end

  def fifty
    time_rand (Time.now - 50.years),(Time.now - 54.years)
  end

  def fifty_five
    time_rand (Time.now - 55.years),(Time.now - 59.years)
  end

  def sixty
    time_rand (Time.now - 60.years),(Time.now - 64.years)
  end

  def sixty_five
    time_rand (Time.now - 65.years),(Time.now - 69.years)
  end

  def old 
    time_rand (Time.now - 20.years),(Time.now - 80.years)
  end

  
  def get_ssn
    @ssn ||= (999999..9999999).begin  
    @ssn = @ssn.next 
    ssn =  "00#{@ssn}"
    Person.encrypt_ssn(ssn) 
  end

  def get_gender
    ["male","female"].sample
  end

  def get_fein
    @ssn ||= (99999999..999999999).begin  
    @ssn = @ssn.next 
    ssn =  "#{@ssn.to_s}"
  end

  def get_hbx_id
    @ssn ||= (999999..9999999).begin  
    @ssn = @ssn.next 
    ssn =  "#{@ssn.to_s}"
  end


  def build_orgs
    puts "********************************* OPM Agency seed started at #{Time.now} ********************************* "

    CSV.foreach("#{Rails.root}/db/seedfiles/opm_agencies.csv", :headers => true) do |row|
      parent_agency = row[3].split('').drop(3).join('')
      @agency_codes[row[4]] = [row[5].split('').drop(5).join(''), parent_agency]
      date = DateTime.now
     org =  {
        "created_at"=>nil,
        "dba"=> "#{row[5].split('').drop(5).join('')}",
        "parent_agency" =>parent_agency,
        "employer_profile"=>
         {"_id" => BSON::ObjectId.new,
          "aasm_state"=>"applicant",
          "logo" => parent_agency.downcase.parameterize.underscore.split('').push(".","p","n","g").join(''),
          "broker_agency_accounts"=>
           [{
            "_id" => BSON::ObjectId.new,
            "broker_agency_profile_id" =>  BrokerAgencyProfile.first.id,
             "created_at"=>nil,
             "end_on"=>nil,
             "is_active"=>true,
             "start_on"=> date,
             "updated_at"=>nil,
             "updated_by"=>nil,
             "updated_by_id"=>nil,
             "writing_agent_id"=>nil}],
          "contact_method"=>"Only Electronic communications",
          "created_at"=>nil,
          "disable_ssn_date"=>nil,
          "enable_ssn_date"=>nil,
          "entity_kind"=>"s_corporation",
          "inbox"=>
           {
            "access_key"=>"5cc45b86ec83a5178d0010a6917af9dfd2cd099ae32f",
            "messages"=>
             [{
              "_id" => BSON::ObjectId.new,
               "body"=>"Test content 1",
               "created_at"=>nil,
               "folder"=>"inbox",
               "from"=>nil,
               "message_read"=>false,
               "parent_message_id"=>nil,
               "subject"=>"Test subject 1",
               "to"=>nil}]},
          "no_ssn"=>false,
          "profile_source"=>"self_serve",
          "registered_on"=>nil,
          "sic_code"=>"1111",
          "updated_at"=>nil,
          "updated_by_id"=>nil,
          "xml_transmitted_timestamp"=>nil},
        "fein"=>get_fein,
        "hbx_id"=>get_hbx_id,
        "home_page"=>nil,
        "is_active"=>nil,
        "is_fake_fein"=>nil,
        "legal_name"=>"#{row[5].split('').drop(5).join('')}",
        "office_locations"=>
         [{
           "address"=>
            {
             "address_1"=>"8637 Cosmic Way, NW",
             "address_2"=>"",
             "address_3"=>"",
             "city"=>"Washington",
             "country_name"=>"",
             "county"=>"County",
             "created_at"=>nil,
             "full_text"=>nil,
             "kind"=>"primary",
             "location_state_code"=>nil,
             "state"=>"DC",
             "updated_at"=>nil,
             "zip"=>"20001"},
           "is_primary"=>true,
           "phone"=>
            {
             "area_code"=>"202",
             "country_code"=>"",
             "created_at"=>nil,
             "extension"=>nil,
             "full_phone_number"=>"2025551213",
             "kind"=>"main",
             "number"=>"5551213",
             "primary"=>nil,
             "updated_at"=>nil}}],
        "updated_at"=>nil,
        "updated_by"=>nil,
        "updated_by_id"=>nil,
        "version"=>1}

      #  @client[:organizations].insert_one org

    end
  end


  def spouse_only(ep,age,name_0,name_1,name_2,family_id_0,family_id_1,status)
    family_member_id_0 = BSON::ObjectId.new
    family_member_id_1 = BSON::ObjectId.new
    family_member_id_2 = BSON::ObjectId.new
    # counter = ln
    @ce_0 = {"_id" => BSON::ObjectId.new,
      "_type" => 'census_employee',
      "aasm_state"=>"eligible",
      "autocomplete"=> nil,
      "census_dependents"=>
      [{ "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "dob"=> fifty,
        "employee_relationship"=>"spouse",
        "employer_assigned_family_id"=>nil,
        "encrypted_ssn"=>get_ssn,
        "first_name"=>name_1.split[0],
        "gender"=>get_gender,
        "last_name"=>name_1.split[1],
        "middle_name"=>nil,
        "name_sfx"=>nil,
        "updated_at"=>nil}],
      "cobra_begin_date"=>nil,
      "coverage_terminated_on"=>nil,
      "created_at"=>nil,
      "dob"=>age,
      "email"=>
      { "_id" => BSON::ObjectId.new,
        "address"=>"dan.thomas@dc.gov",
        "created_at"=>nil,
        "kind"=>"work",
        "updated_at"=>nil},
      "employee_relationship"=>"employee",
      "employee_role_id"=>nil,
      "employer_assigned_family_id"=>nil,
      "employer_profile_id"=>ep.id,
      "employment_terminated_on"=>nil,
      "encrypted_ssn"=> get_ssn,
      "first_name"=>name_0.split[0],
      "gender"=>"male",
      "hired_on"=>Time.new("2017,04,03"),
      "is_business_owner"=>true,
      "last_name"=>name_0.split[1],
      "middle_name"=>nil,
      "name_sfx"=>nil,
      "no_ssn_allowed"=>false,
      "updated_at"=>nil}

      @ce_1 = {"_id" => BSON::ObjectId.new,
        "_type" => 'census_employee',
        "aasm_state"=>"eligible",
        "autocomplete"=> nil,
        "cobra_begin_date"=>nil,
        "coverage_terminated_on"=>young,
        "created_at"=>nil,
        "dob"=>old,
        "email"=>
        { "_id" => BSON::ObjectId.new,
          "address"=>"dan.thomas@dc.gov",
          "created_at"=>nil,
          "kind"=>"work",
          "updated_at"=>nil},
        "employee_relationship"=>"employee",
        "employee_role_id"=>nil,
        "employer_assigned_family_id"=>nil,
        "employer_profile_id"=>ep.id,
        "employment_terminated_on"=>nil,
        "encrypted_ssn"=> get_ssn,
        "first_name"=>name_1.split[0],
        "gender"=>"male",
        "hired_on"=>Time.new("2017,04,03"),
        "is_business_owner"=>true,
        "last_name"=>name_1.split[1],
        "middle_name"=>nil,
        "name_sfx"=>nil,
        "no_ssn_allowed"=>false,
        "updated_at"=>nil}

  p0_id =  BSON::ObjectId.new
  p1_id = BSON::ObjectId.new
  p2_id = BSON::ObjectId.new
  p3_id = BSON::ObjectId.new

  p0 = {
    "_id" => p0_id,
  "alternate_name"=>nil,
  "broker_agency_contact_id"=>nil,
  "created_at"=>nil,
  "date_of_death"=>nil,
  "dob"=> Date.new(1976,2,2),
  "dob_check"=>nil,
  "employer_contact_id"=>nil,
  "encrypted_ssn"=> @ce_0['encrypted_ssn'],
  "person_relationships"=>
  [{"_id"=>BSON::ObjectId.new,
    "created_at"=>nil,
    "kind"=>"spouse",
    "updated_at"=>nil,
    "predecessor_id" => p2_id,
     "successor_id"=> p0_id, 
     "family_id" => family_id_0},

  ],
  "ethnicity"=>nil,
  "first_name"=>name_0.split[0],
  "full_name"=>name_0,
  "gender"=>get_gender,
  "general_agency_contact_id"=>nil,
  "hbx_id"=>get_hbx_id,
  "is_active"=>true,
  "is_disabled"=>nil,
  "is_homeless"=>false,
  "is_incarcerated"=>nil,
  "is_physically_disabled"=>nil,
  "is_temporarily_out_of_state"=>false,
  "is_tobacco_user"=>"unknown",
  "language_code"=>nil,
  "last_name"=>name_0.split[1],
  "middle_name"=>nil,
  "modifier_id"=>nil,
  "name_pfx"=>nil,
  "name_sfx"=>nil,
  "no_dc_address"=>false,
  "no_ssn"=>nil,
  "race"=>nil,
  "tracking_version"=>1,
  "tribal_id"=>nil,
  "updated_at"=>nil,
  "updated_by"=>nil,
  "updated_by_id"=>nil,
  "user_id"=> get_hbx_id,
  "employee_roles"=>
  [{"_id"=>BSON::ObjectId('5cc6f28cec83a57a36000869'),
    "benefit_group_id"=>nil,
    "bookmark_url"=>nil,
    "census_employee_id"=>nil,
    "contact_method"=>"Paper and Electronic communications",
    "created_at"=>nil,
    "employer_profile_id"=>ep.id,
    "employment_status"=>"active",
    "hired_on"=>Date.new(2018,2,2),
    "is_active"=>true,
    "language_preference"=>"English",
    "terminated_on"=>nil,
    "updated_at"=>nil,
    "updated_by_id"=>nil}],
  "version"=>1}


  p1 = {
    "_id" =>p1_id,
    "alternate_name"=>nil,
    "broker_agency_contact_id"=>nil,
    "created_at"=>nil,
    "date_of_death"=>nil,
    "dob"=> @ce_1['dob'],
    "dob_check"=>nil,
    "employer_contact_id"=>nil,
    "encrypted_ssn"=> @ce_1['encrypted_ssn'],
    "ethnicity"=>nil,
    "first_name"=>name_1.split[0],
    "full_name"=>name_1,

    "gender"=>get_gender,
    "general_agency_contact_id"=>nil,
    "hbx_id"=>get_hbx_id,
    "is_active"=>true,
    "is_disabled"=>nil,
    "is_homeless"=>false,
    "is_incarcerated"=>nil,
    "is_physically_disabled"=>nil,
    "is_temporarily_out_of_state"=>false,
    "is_tobacco_user"=>"unknown",
    "language_code"=>nil,
    "last_name"=>name_1.split[1],
    "middle_name"=>nil,
    "modifier_id"=>nil,
    "name_pfx"=>nil,
    "name_sfx"=>nil,
    "no_dc_address"=>false,
    "no_ssn"=>nil,
    "race"=>nil,
    "tracking_version"=>1,
    "tribal_id"=>nil,
    "updated_at"=>nil,
    "updated_by"=>nil,
    "updated_by_id"=>nil,
    "user_id"=> get_hbx_id,
    "version"=>1,
    "employee_roles"=>
    [{"_id"=>BSON::ObjectId('5cc6f28cec83a57a36000869'),
      "benefit_group_id"=>nil,
      "bookmark_url"=>nil,
      "census_employee_id"=>nil,
      "contact_method"=>"Paper and Electronic communications",
      "created_at"=>nil,
      "employer_profile_id"=>ep.id,
      "employment_status"=>status,
      "hired_on"=>Date.new(2018,2,2),
      "is_active"=>true,
      "language_preference"=>"English",
      "terminated_on"=>nil,
      "updated_at"=>nil,
      "updated_by_id"=>nil}],}


  p2 = {
    "_id" => p2_id,
    "alternate_name"=>nil,
    "broker_agency_contact_id"=>nil,
    "created_at"=>nil,
    "date_of_death"=>nil,
    "dob"=> @ce_0['census_dependents'][0]['dob'],
    "dob_check"=>nil,
    "employer_contact_id"=>nil,
    "encrypted_ssn"=> @ce_0['census_dependents'][0]['encrypted_ssn'],
    "ethnicity"=>nil,
    "first_name"=>name_2.split[0],
    "full_name"=>name_2,
    "gender"=>get_gender,
    "general_agency_contact_id"=>nil,
    "hbx_id"=>get_hbx_id,
    "person_relationships"=>
    [{"_id"=>BSON::ObjectId.new,
      "created_at"=>nil,
      "kind"=>"spouse",
      "updated_at"=>nil,
      "predecessor_id" =>p2_id,
      "successor_id"=> p0_id, 
      "family_id" => family_id_0}],
    "is_active"=>true,
    "is_disabled"=>nil,
    "is_homeless"=>false,
    "is_incarcerated"=>nil,
    "is_physically_disabled"=>nil,
    "is_temporarily_out_of_state"=>false,
    "is_tobacco_user"=>"unknown",
    "language_code"=>nil,
    "last_name"=>name_2.split[1],
    "middle_name"=>nil,
    "modifier_id"=>nil,
    "name_pfx"=>nil,
    "name_sfx"=>nil,
    "no_dc_address"=>false,
    "no_ssn"=>nil,
    "race"=>nil,
    "tracking_version"=>1,
    "tribal_id"=>nil,
    "updated_at"=>nil,
    "updated_by"=>nil,
    "updated_by_id"=>nil,
    "user_id"=> get_hbx_id,
    "version"=>1}





  # @client[:people].insert_one p3

  # @client[:census_members].insert_one @ce_0
  # @client[:census_members].insert_one @ce_1


  family_member_id_0 = BSON::ObjectId.new
  family_member_id_1 = BSON::ObjectId.new
  family_member_id_2 = BSON::ObjectId.new
  family_member_id_3 = BSON::ObjectId.new


fam = {
"_id" => family_id_0,
"application_type"=>nil,
"created_at"=>nil,
"e_case_id"=>nil,
"e_status_code"=>nil,
"family_members"=>
[{ "_id" => family_member_id_0,
"broker_role_id"=>nil,
"created_at"=>nil,
"former_family_id"=>nil,
"is_active"=>true,
"is_consent_applicant"=>false,
"is_coverage_applicant"=>true,
"is_primary_applicant"=>true,
"person_id"=> p0['_id'],
"updated_at"=>nil,
"updated_by_id"=>nil},
{ "_id" => family_member_id_1,
  "broker_role_id"=>nil,
  "created_at"=>nil,
  "former_family_id"=>nil,
  "is_active"=>true,
  "is_consent_applicant"=>false,
  "is_coverage_applicant"=>true,
  "is_primary_applicant"=>false,
  "person_id"=> p2['_id'],
  "updated_at"=>nil,
  "updated_by_id"=>nil}
],
"haven_app_id"=>nil,
"hbx_assigned_id"=>10002,
"households"=>
[{    "_id" => BSON::ObjectId.new,
"coverage_households"=>
 [{    "_id" => BSON::ObjectId.new,
   "aasm_state"=>"applicant",
   "broker_agency_id"=>nil,
   "coverage_household_members"=>
    [{    "_id" => BSON::ObjectId.new,
      "created_at"=>nil,
      "family_member_id"=> family_member_id_0,
      "is_subscriber"=>true,
      "updated_at"=>nil },
      {    "_id" => BSON::ObjectId.new,
      "created_at"=>nil,
      "family_member_id"=> family_member_id_1,
      "is_subscriber"=>false,
      "updated_at"=>nil },

    ],
   "created_at"=>nil,
   "is_determination_split_household"=>false,
   "is_immediate_family"=>true,
   "submitted_at"=>nil,
   "updated_at"=>nil,
   "updated_by_id"=>nil,
   "writing_agent_id"=>nil},
  {"_id"=>BSON::ObjectId.new,
   "aasm_state"=>"applicant",
   "broker_agency_id"=>nil,
   "created_at"=>nil,
   "is_determination_split_household"=>false,
   "is_immediate_family"=>false,
   "submitted_at"=>nil,
   "updated_at"=>nil,
   "updated_by_id"=>nil,
   "writing_agent_id"=>nil}],
"created_at"=>nil,
"effective_ending_on"=>Date.new(2020,5,5),
"effective_starting_on"=>Date.new(2019,5,6),
"irs_group_id"=>BSON::ObjectId.new,
"is_active"=>true,
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by_id"=>nil}],
"irs_groups"=>
[{"_id"=>BSON::ObjectId.new,
"created_at"=>nil,
"effective_ending_on"=>Date.new(2020,5,5),
"effective_starting_on"=>Date.new(2020,5,5),
"hbx_assigned_id"=>nil,
"is_active"=>true,
"updated_at"=>nil,
"updated_by_id"=>nil}],
"is_active"=>true,
"is_applying_for_assistance"=>nil,
"min_verification_due_date"=>nil,
"person_id"=>nil,
"renewal_consent_through_year"=>nil,
"status"=>"",
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by"=>nil,
"updated_by_id"=>nil,
"version"=>1,
"vlp_documents_status"=>nil}

family_1 = {
"_id" => family_id_1,
"application_type"=>nil,
"created_at"=>nil,
"e_case_id"=>nil,
"e_status_code"=>nil,
"family_members"=>
[{ "_id" => family_member_id_2,
  "broker_role_id"=>nil,
  "created_at"=>nil,
  "former_family_id"=>nil,
  "is_active"=>true,
  "is_consent_applicant"=>false,
  "is_coverage_applicant"=>true,
  "is_primary_applicant"=>true,
  "person_id"=> p1['_id'],
  "updated_at"=>nil,
  "updated_by_id"=>nil}

],
"haven_app_id"=>nil,
"hbx_assigned_id"=>10002,
"households"=>
[{    "_id" => BSON::ObjectId.new,
  "coverage_households"=>
   [{    "_id" => BSON::ObjectId.new,
     "aasm_state"=>"applicant",
     "broker_agency_id"=>nil,
     "coverage_household_members"=>
      [{    "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "family_member_id"=> family_member_id_2,
        "is_subscriber"=>true,
        "updated_at"=>nil },
        {    "_id" => BSON::ObjectId.new,
          "created_at"=>nil,
          "family_member_id"=> family_member_id_3,
          "is_subscriber"=>true,
          "updated_at"=>nil }

      ],
     "created_at"=>nil,
     "is_determination_split_household"=>false,
     "is_immediate_family"=>true,
     "submitted_at"=>nil,
     "updated_at"=>nil,
     "updated_by_id"=>nil,
     "writing_agent_id"=>nil},
    {"_id"=>BSON::ObjectId.new,
     "aasm_state"=>"applicant",
     "broker_agency_id"=>nil,
     "created_at"=>nil,
     "is_determination_split_household"=>false,
     "is_immediate_family"=>false,
     "submitted_at"=>nil,
     "updated_at"=>nil,
     "updated_by_id"=>nil,
     "writing_agent_id"=>nil}],
  "created_at"=>nil,
  "effective_ending_on"=>Date.new(2020,5,5),
  "effective_starting_on"=>Date.new(2019,5,6),
  "irs_group_id"=>BSON::ObjectId.new,
  "is_active"=>true,
  "submitted_at"=>nil,
  "updated_at"=>nil,
  "updated_by_id"=>nil}],
"irs_groups"=>
[{"_id"=>BSON::ObjectId.new,
  "created_at"=>nil,
  "effective_ending_on"=>Date.new(2020,5,5),
  "effective_starting_on"=>Date.new(2020,5,5),
  "hbx_assigned_id"=>nil,
  "is_active"=>true,
  "updated_at"=>nil,
  "updated_by_id"=>nil}],
"is_active"=>true,
"is_applying_for_assistance"=>nil,
"min_verification_due_date"=>nil,
"person_id"=>nil,
"renewal_consent_through_year"=>nil,
"status"=>"",
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by"=>nil,
"updated_by_id"=>nil,
"version"=>1,
"vlp_documents_status"=>nil}


# @client[:families].insert_one fam
# @client[:families].insert_one family_1

@people.push(p0, p1, p2)
@ces.push(@ce_0, @ce_10)
@families.push(fam, family_1)

end

  def spouse_and_kid(ep,age,name_0,name_1,name_2,name_3,family_id_0,family_id_1,status)
    family_member_id_0 = BSON::ObjectId.new
    family_member_id_1 = BSON::ObjectId.new
    family_member_id_2 = BSON::ObjectId.new
    @ce_0 = {"_id" => BSON::ObjectId.new,
      "_type" => 'census_employee',
      "aasm_state"=>"eligible",
      "autocomplete"=> nil,
      "census_dependents"=>
      [{ "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "dob"=> fifty,
        "employee_relationship"=>"spouse",
        "employer_assigned_family_id"=>nil,
        "encrypted_ssn"=>get_ssn,
        "first_name"=>name_1.split[0],
        "gender"=>get_gender,
        "last_name"=>name_1.split[1],
        "middle_name"=>nil,
        "name_sfx"=>nil,
        "updated_at"=>nil},
        { "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "dob"=> young,
        "employee_relationship"=>"child_under_26",
        "employer_assigned_family_id"=>nil,
        "encrypted_ssn"=>get_ssn,
        "first_name"=>name_2.split[0],
        "gender"=>get_gender,
        "last_name"=>name_2.split[1],
        "middle_name"=>nil,
        "name_sfx"=>nil,
        "updated_at"=>nil}],
      "cobra_begin_date"=>nil,
      "coverage_terminated_on"=>nil,
      "created_at"=>nil,
      "dob"=>age,
      "email"=>
      { "_id" => BSON::ObjectId.new,
        "address"=>"dan.thomas@dc.gov",
        "created_at"=>nil,
        "kind"=>"work",
        "updated_at"=>nil},
      "employee_relationship"=>"employee",
      "employee_role_id"=>nil,
      "employer_assigned_family_id"=>nil,
      "employer_profile_id"=>ep.id,
      "employment_terminated_on"=>nil,
      "encrypted_ssn"=> get_ssn,
      "first_name"=>name_0.split[0],
      "gender"=>"male",
      "hired_on"=>Time.new("2017,04,03"),
      "is_business_owner"=>true,
      "last_name"=>name_0.split[1],
      "middle_name"=>nil,
      "name_sfx"=>nil,
      "no_ssn_allowed"=>false,
      "updated_at"=>nil}

      @ce_1 = {"_id" => BSON::ObjectId.new,
        "_type" => 'census_employee',
        "aasm_state"=>"eligible",
        "autocomplete"=> nil,
        "cobra_begin_date"=>nil,
        "coverage_terminated_on"=>young,
        "created_at"=>nil,
        "dob"=>old,
        "email"=>
        { "_id" => BSON::ObjectId.new,
          "address"=>"dan.thomas@dc.gov",
          "created_at"=>nil,
          "kind"=>"work",
          "updated_at"=>nil},
        "employee_relationship"=>"employee",
        "employee_role_id"=>nil,
        "employer_assigned_family_id"=>nil,
        "employer_profile_id"=>ep.id,
        "employment_terminated_on"=>nil,
        "encrypted_ssn"=> get_ssn,
        "first_name"=>name_1.split[0],
        "gender"=>"male",
        "hired_on"=>Time.new("2017,04,03"),
        "is_business_owner"=>true,
        "last_name"=>name_1.split[1],
        "middle_name"=>nil,
        "name_sfx"=>nil,
        "no_ssn_allowed"=>false,
        "updated_at"=>nil}

  p0_id =  BSON::ObjectId.new
  p1_id = BSON::ObjectId.new
  p2_id = BSON::ObjectId.new
  p3_id = BSON::ObjectId.new

  p0 = {
    "_id" => p0_id,
  "alternate_name"=>nil,
  "broker_agency_contact_id"=>nil,
  "created_at"=>nil,
  "date_of_death"=>nil,
  "dob"=> Date.new(1976,2,2),
  "dob_check"=>nil,
  "employer_contact_id"=>nil,
  "encrypted_ssn"=> @ce_0['encrypted_ssn'],
  "person_relationships"=>
  [{"_id"=>BSON::ObjectId.new,
    "created_at"=>nil,
    "kind"=>"spouse",
    "updated_at"=>nil,
    "predecessor_id" => p2_id,
     "successor_id"=> p0_id, 
     "family_id" => family_id_0},
     {"_id"=>BSON::ObjectId.new,
     "created_at"=>nil,
     "kind"=>"child",
     "updated_at"=>nil,
     "predecessor_id" => p3_id,
      "successor_id"=> p0_id, 
      "family_id" => family_id_0}],
  "ethnicity"=>nil,
  "first_name"=>name_0.split[0],
  "full_name"=>name_0,
  "gender"=>get_gender,
  "general_agency_contact_id"=>nil,
  "hbx_id"=>get_hbx_id,
  "is_active"=>true,
  "is_disabled"=>nil,
  "is_homeless"=>false,
  "is_incarcerated"=>nil,
  "is_physically_disabled"=>nil,
  "is_temporarily_out_of_state"=>false,
  "is_tobacco_user"=>"unknown",
  "language_code"=>nil,
  "last_name"=>name_0.split[1],
  "middle_name"=>nil,
  "modifier_id"=>nil,
  "name_pfx"=>nil,
  "name_sfx"=>nil,
  "no_dc_address"=>false,
  "no_ssn"=>nil,
  "race"=>nil,
  "tracking_version"=>1,
  "tribal_id"=>nil,
  "updated_at"=>nil,
  "updated_by"=>nil,
  "updated_by_id"=>nil,
  "user_id"=> get_hbx_id,
  "employee_roles"=>
  [{"_id"=>BSON::ObjectId('5cc6f28cec83a57a36000869'),
    "benefit_group_id"=>nil,
    "bookmark_url"=>nil,
    "census_employee_id"=>nil,
    "contact_method"=>"Paper and Electronic communications",
    "created_at"=>nil,
    "employer_profile_id"=>ep.id,
    "employment_status"=>"active",
    "hired_on"=>Date.new(2018,2,2),
    "is_active"=>true,
    "language_preference"=>"English",
    "terminated_on"=>nil,
    "updated_at"=>nil,
    "updated_by_id"=>nil}],
  "version"=>1}


  p1 = {
    "_id" =>p1_id,
    "alternate_name"=>nil,
    "broker_agency_contact_id"=>nil,
    "created_at"=>nil,
    "date_of_death"=>nil,
    "dob"=> @ce_1['dob'],
    "dob_check"=>nil,
    "employer_contact_id"=>nil,
    "encrypted_ssn"=> @ce_1['encrypted_ssn'],
    "ethnicity"=>nil,
    "first_name"=>name_1.split[0],
    "full_name"=>name_1,
    "gender"=>get_gender,
    "general_agency_contact_id"=>nil,
    "hbx_id"=>get_hbx_id,
    "is_active"=>true,
    "is_disabled"=>nil,
    "is_homeless"=>false,
    "is_incarcerated"=>nil,
    "is_physically_disabled"=>nil,
    "is_temporarily_out_of_state"=>false,
    "is_tobacco_user"=>"unknown",
    "language_code"=>nil,
    "last_name"=>name_1.split[1],
    "middle_name"=>nil,
    "modifier_id"=>nil,
    "name_pfx"=>nil,
    "name_sfx"=>nil,
    "no_dc_address"=>false,
    "no_ssn"=>nil,
    "race"=>nil,
    "tracking_version"=>1,
    "tribal_id"=>nil,
    "updated_at"=>nil,
    "updated_by"=>nil,
    "updated_by_id"=>nil,
    "user_id"=> get_hbx_id,
    "version"=>1,
    "employee_roles"=>
    [{"_id"=>BSON::ObjectId('5cc6f28cec83a57a36000869'),
      "benefit_group_id"=>nil,
      "bookmark_url"=>nil,
      "census_employee_id"=>nil,
      "contact_method"=>"Paper and Electronic communications",
      "created_at"=>nil,
      "employer_profile_id"=>ep.id,
      "employment_status"=>status,
      "hired_on"=>Date.new(2018,2,2),
      "is_active"=>true,
      "language_preference"=>"English",
      "terminated_on"=>nil,
      "updated_at"=>nil,
      "updated_by_id"=>nil}],}


  p2 = {
    "_id" => p2_id,
    "alternate_name"=>nil,
    "broker_agency_contact_id"=>nil,
    "created_at"=>nil,
    "date_of_death"=>nil,
    "dob"=> @ce_0['census_dependents'][0]['dob'],
    "dob_check"=>nil,
    "employer_contact_id"=>nil,
    "encrypted_ssn"=> @ce_0['census_dependents'][0]['encrypted_ssn'],
    "ethnicity"=>nil,
    "first_name"=>name_2.split[0],
    "full_name"=>name_2,
    "gender"=>get_gender,
    "general_agency_contact_id"=>nil,
    "hbx_id"=>get_hbx_id,
    "person_relationships"=>
    [{"_id"=>BSON::ObjectId.new,
      "created_at"=>nil,
      "kind"=>"spouse",
      "updated_at"=>nil,
      "predecessor_id" =>p2_id,
      "successor_id"=> p0_id, 
      "family_id" => family_id_0}],
    "is_active"=>true,
    "is_disabled"=>nil,
    "is_homeless"=>false,
    "is_incarcerated"=>nil,
    "is_physically_disabled"=>nil,
    "is_temporarily_out_of_state"=>false,
    "is_tobacco_user"=>"unknown",
    "language_code"=>nil,
    "last_name"=>name_2.split[1],
    "middle_name"=>nil,
    "modifier_id"=>nil,
    "name_pfx"=>nil,
    "name_sfx"=>nil,
    "no_dc_address"=>false,
    "no_ssn"=>nil,
    "race"=>nil,
    "tracking_version"=>1,
    "tribal_id"=>nil,
    "updated_at"=>nil,
    "updated_by"=>nil,
    "updated_by_id"=>nil,
    "user_id"=> get_hbx_id,
    "version"=>1}

  p3 = {
    "_id" => p3_id,
    "alternate_name"=>nil,
    "broker_agency_contact_id"=>nil,
    "created_at"=>nil,
    "date_of_death"=>nil,
    "dob"=> @ce_0['census_dependents'][1]['dob'],
    "dob_check"=>nil,
    "employer_contact_id"=>nil,
    "encrypted_ssn"=> @ce_0['census_dependents'][1]['encrypted_ssn'],
    "ethnicity"=>nil,
    "first_name"=>name_3.split[0],
    "full_name"=>name_3,
    "person_relationships"=>
    [{"_id"=>BSON::ObjectId.new,
      "created_at"=>nil,
      "kind"=>"child",
      "updated_at"=>nil,
      "predecessor_id" =>p3_id,
      "successor_id"=> p0_id, 
      "family_id" => family_id_0}],
    "gender"=>get_gender,
    "general_agency_contact_id"=>nil,
    "hbx_id"=>get_hbx_id,
    "is_active"=>true,
    "is_disabled"=>nil,
    "is_homeless"=>false,
    "is_incarcerated"=>nil,
    "is_physically_disabled"=>nil,
    "is_temporarily_out_of_state"=>false,
    "is_tobacco_user"=>"unknown",
    "language_code"=>nil,
    "middle_name"=>nil,
    "modifier_id"=>nil,
    "last_name"=>name_3.split[1],
    "name_pfx"=>nil,
    "name_sfx"=>nil,
    "no_dc_address"=>false,
    "no_ssn"=>nil,
    "race"=>nil,
    "tracking_version"=>1,
    "tribal_id"=>nil,
    "updated_at"=>nil,
    "updated_by"=>nil,
    "updated_by_id"=>nil,
    "user_id"=> get_hbx_id,
    "version"=>1}


  @client[:people].insert_one p0
  @client[:people].insert_one p1
  @client[:people].insert_one p2
  @client[:people].insert_one p3

  @client[:census_members].insert_one @ce_0
  @client[:census_members].insert_one @ce_1


  family_member_id_0 = BSON::ObjectId.new
  family_member_id_1 = BSON::ObjectId.new
  family_member_id_2 = BSON::ObjectId.new
  family_member_id_3 = BSON::ObjectId.new


  family_0 = {
"_id" => family_id_0,
"application_type"=>nil,
"created_at"=>nil,
"e_case_id"=>nil,
"e_status_code"=>nil,
"family_members"=>
[{ "_id" => family_member_id_0,
"broker_role_id"=>nil,
"created_at"=>nil,
"former_family_id"=>nil,
"is_active"=>true,
"is_consent_applicant"=>false,
"is_coverage_applicant"=>true,
"is_primary_applicant"=>true,
"person_id"=> p0['_id'],
"updated_at"=>nil,
"updated_by_id"=>nil},
{ "_id" => family_member_id_1,
"broker_role_id"=>nil,
"created_at"=>nil,
"former_family_id"=>nil,
"is_active"=>true,
"is_consent_applicant"=>false,
"is_coverage_applicant"=>true,
"is_primary_applicant"=>false,
"person_id"=> p2['_id'],
"updated_at"=>nil,
"updated_by_id"=>nil},
{ "_id" => family_member_id_2,
"broker_role_id"=>nil,
"created_at"=>nil,
"former_family_id"=>nil,
"is_active"=>true,
"is_consent_applicant"=>false,
"is_coverage_applicant"=>true,
"is_primary_applicant"=>false,
"person_id"=> p3['_id'],
"updated_at"=>nil,
"updated_by_id"=>nil},
],
"haven_app_id"=>nil,
"hbx_assigned_id"=>10002,
"households"=>
[{    "_id" => BSON::ObjectId.new,
"coverage_households"=>
 [{    "_id" => BSON::ObjectId.new,
   "aasm_state"=>"applicant",
   "broker_agency_id"=>nil,
   "coverage_household_members"=>
    [{    "_id" => BSON::ObjectId.new,
      "created_at"=>nil,
      "family_member_id"=> family_member_id_0,
      "is_subscriber"=>true,
      "updated_at"=>nil },
      {    "_id" => BSON::ObjectId.new,
      "created_at"=>nil,
      "family_member_id"=> family_member_id_1,
      "is_subscriber"=>false,
      "updated_at"=>nil },
      {    "_id" => BSON::ObjectId.new,
      "created_at"=>nil,
      "family_member_id"=> family_member_id_2,
      "is_subscriber"=>false,
      "updated_at"=>nil }

    ],
   "created_at"=>nil,
   "is_determination_split_household"=>false,
   "is_immediate_family"=>true,
   "submitted_at"=>nil,
   "updated_at"=>nil,
   "updated_by_id"=>nil,
   "writing_agent_id"=>nil},
  {"_id"=>BSON::ObjectId.new,
   "aasm_state"=>"applicant",
   "broker_agency_id"=>nil,
   "created_at"=>nil,
   "is_determination_split_household"=>false,
   "is_immediate_family"=>false,
   "submitted_at"=>nil,
   "updated_at"=>nil,
   "updated_by_id"=>nil,
   "writing_agent_id"=>nil}],
"created_at"=>nil,
"effective_ending_on"=>Date.new(2020,5,5),
"effective_starting_on"=>Date.new(2019,5,6),
"irs_group_id"=>BSON::ObjectId.new,
"is_active"=>true,
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by_id"=>nil}],
"irs_groups"=>
[{"_id"=>BSON::ObjectId.new,
"created_at"=>nil,
"effective_ending_on"=>Date.new(2020,5,5),
"effective_starting_on"=>Date.new(2020,5,5),
"hbx_assigned_id"=>nil,
"is_active"=>true,
"updated_at"=>nil,
"updated_by_id"=>nil}],
"is_active"=>true,
"is_applying_for_assistance"=>nil,
"min_verification_due_date"=>nil,
"person_id"=>nil,
"renewal_consent_through_year"=>nil,
"status"=>"",
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by"=>nil,
"updated_by_id"=>nil,
"version"=>1,
"vlp_documents_status"=>nil}

family_1 = {
"_id" => family_id_1,
"application_type"=>nil,
"created_at"=>nil,
"e_case_id"=>nil,
"e_status_code"=>nil,
"family_members"=>
[{ "_id" => family_member_id_1,
  "broker_role_id"=>nil,
  "created_at"=>nil,
  "former_family_id"=>nil,
  "is_active"=>true,
  "is_consent_applicant"=>false,
  "is_coverage_applicant"=>true,
  "is_primary_applicant"=>true,
  "person_id"=> p1['_id'],
  "updated_at"=>nil,
  "updated_by_id"=>nil}

],
"haven_app_id"=>nil,
"hbx_assigned_id"=>10002,
"households"=>
[{    "_id" => BSON::ObjectId.new,
  "coverage_households"=>
   [{    "_id" => BSON::ObjectId.new,
     "aasm_state"=>"applicant",
     "broker_agency_id"=>nil,
     "coverage_household_members"=>
      [{    "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "family_member_id"=> family_member_id_3,
        "is_subscriber"=>true,
        "updated_at"=>nil }

      ],
     "created_at"=>nil,
     "is_determination_split_household"=>false,
     "is_immediate_family"=>true,
     "submitted_at"=>nil,
     "updated_at"=>nil,
     "updated_by_id"=>nil,
     "writing_agent_id"=>nil},
    {"_id"=>BSON::ObjectId.new,
     "aasm_state"=>"applicant",
     "broker_agency_id"=>nil,
     "created_at"=>nil,
     "is_determination_split_household"=>false,
     "is_immediate_family"=>false,
     "submitted_at"=>nil,
     "updated_at"=>nil,
     "updated_by_id"=>nil,
     "writing_agent_id"=>nil}],
  "created_at"=>nil,
  "effective_ending_on"=>Date.new(2020,5,5),
  "effective_starting_on"=>Date.new(2019,5,6),
  "irs_group_id"=>BSON::ObjectId.new,
  "is_active"=>true,
  "submitted_at"=>nil,
  "updated_at"=>nil,
  "updated_by_id"=>nil}],
"irs_groups"=>
[{"_id"=>BSON::ObjectId.new,
  "created_at"=>nil,
  "effective_ending_on"=>Date.new(2020,5,5),
  "effective_starting_on"=>Date.new(2020,5,5),
  "hbx_assigned_id"=>nil,
  "is_active"=>true,
  "updated_at"=>nil,
  "updated_by_id"=>nil}],
"is_active"=>true,
"is_applying_for_assistance"=>nil,
"min_verification_due_date"=>nil,
"person_id"=>nil,
"renewal_consent_through_year"=>nil,
"status"=>"",
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by"=>nil,
"updated_by_id"=>nil,
"version"=>1,
"vlp_documents_status"=>nil}


@client[:families].insert_one family_0
@client[:families].insert_one family_1

# puts 

  end



  def big_fam(ep,age,name_0,name_1,name_2,name_3,name_4,family_id_0,family_id_1, status)
    family_member_id_0 = BSON::ObjectId.new
    family_member_id_1 = BSON::ObjectId.new
    family_member_id_2 = BSON::ObjectId.new
    # counter = ln
    @ce_0 = {"_id" => BSON::ObjectId.new,
      "_type" => 'census_employee',
      "aasm_state"=>"eligible",
      "autocomplete"=> nil,
      "census_dependents"=>
      [{ "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "dob"=> fifty,
        "employee_relationship"=>"spouse",
        "employer_assigned_family_id"=>nil,
        "encrypted_ssn"=>get_ssn,
        "first_name"=>name_1.split[0],
        "gender"=>get_gender,
        "last_name"=>name_1.split[1],
        "middle_name"=>nil,
        "name_sfx"=>nil,
        "updated_at"=>nil},
        { "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "dob"=> young,
        "employee_relationship"=>"child_under_26",
        "employer_assigned_family_id"=>nil,
        "encrypted_ssn"=>get_ssn,
        "first_name"=>name_2.split[0],
        "gender"=>get_gender,
        "last_name"=>name_2.split[1],
        "middle_name"=>nil,
        "name_sfx"=>nil,
        "updated_at"=>nil},
        { "_id" => BSON::ObjectId.new,
          "created_at"=>nil,
          "dob"=> young,
          "employee_relationship"=>"child_under_26",
          "employer_assigned_family_id"=>nil,
          "encrypted_ssn"=>get_ssn,
          "first_name"=>name_3.split[0],
          "gender"=>get_gender,
          "last_name"=>name_3.split[1],
          "middle_name"=>nil,
          "name_sfx"=>nil,
          "updated_at"=>nil},
          { "_id" => BSON::ObjectId.new,
            "created_at"=>nil,
            "dob"=> young,
            "employee_relationship"=>"child_under_26",
            "employer_assigned_family_id"=>nil,
            "encrypted_ssn"=>get_ssn,
            "first_name"=>name_4.split[0],
            "gender"=>get_gender,
            "last_name"=>name_4.split[1],
            "middle_name"=>nil,
            "name_sfx"=>nil,
            "updated_at"=>nil}],
      "cobra_begin_date"=>nil,
      "coverage_terminated_on"=>nil,
      "created_at"=>nil,
      "dob"=>age,
      "email"=>
      { "_id" => BSON::ObjectId.new,
        "address"=>"dan.thomas@dc.gov",
        "created_at"=>nil,
        "kind"=>"work",
        "updated_at"=>nil},
      "employee_relationship"=>"employee",
      "employee_role_id"=>nil,
      "employer_assigned_family_id"=>nil,
      "employer_profile_id"=>ep.id,
      "employment_terminated_on"=>nil,
      "encrypted_ssn"=> get_ssn,
      "first_name"=>name_0.split[0],
      "gender"=>"male",
      "hired_on"=>Time.new("2017,04,03"),
      "is_business_owner"=>true,
      "last_name"=>name_0.split[1],
      "middle_name"=>nil,
      "name_sfx"=>nil,
      "no_ssn_allowed"=>false,
      "updated_at"=>nil}

      @ce_1 = {"_id" => BSON::ObjectId.new,
        "_type" => 'census_employee',
        "aasm_state"=>"eligible",
        "autocomplete"=> nil,
        "census_dependents"=>
        [{ "_id" => BSON::ObjectId.new,
          "created_at"=>nil,
          "dob"=> fifty,
          "employee_relationship"=>"spouse",
          "employer_assigned_family_id"=>nil,
          "encrypted_ssn"=>get_ssn,
          "first_name"=>name_1.split[0],
          "gender"=>get_gender,
          "last_name"=>name_1.split[1],
          "middle_name"=>nil,
          "name_sfx"=>nil,
          "updated_at"=>nil},
          { "_id" => BSON::ObjectId.new,
          "created_at"=>nil,
          "dob"=> young,
          "employee_relationship"=>"child_under_26",
          "employer_assigned_family_id"=>nil,
          "encrypted_ssn"=>get_ssn,
          "first_name"=>name_2.split[0],
          "gender"=>get_gender,
          "last_name"=>name_2.split[1],
          "middle_name"=>nil,
          "name_sfx"=>nil,
          "updated_at"=>nil},
          { "_id" => BSON::ObjectId.new,
          "created_at"=>nil,
          "dob"=>young,
          "employee_relationship"=>"child_under_26",
          "employer_assigned_family_id"=>nil,
          "encrypted_ssn"=>get_ssn,
          "first_name"=>name_3.split[0],
          "gender"=>"male",
          "last_name"=>name_3.split[1],
          "middle_name"=>nil,
          "name_sfx"=>nil,
          "updated_at"=> nil}],
        "cobra_begin_date"=>nil,
        "coverage_terminated_on"=>young,
        "created_at"=>nil,
        "dob"=>old,
        "email"=>
        { "_id" => BSON::ObjectId.new,
          "address"=>"dan.thomas@dc.gov",
          "created_at"=>nil,
          "kind"=>"work",
          "updated_at"=>nil},
        "employee_relationship"=>"employee",
        "employee_role_id"=>nil,
        "employer_assigned_family_id"=>nil,
        "employer_profile_id"=>ep.id,
        "employment_terminated_on"=>nil,
        "encrypted_ssn"=> get_ssn,
        "first_name"=>name_1.split[0],
        "gender"=>"male",
        "hired_on"=>Time.new("2017,04,03"),
        "is_business_owner"=>true,
        "last_name"=>name_1.split[1],
        "middle_name"=>nil,
        "name_sfx"=>nil,
        "no_ssn_allowed"=>false,
        "updated_at"=>nil}

  p0_id =  BSON::ObjectId.new
  p1_id = BSON::ObjectId.new
  p2_id = BSON::ObjectId.new
  p3_id = BSON::ObjectId.new
  p4_id = BSON::ObjectId.new


  p0 = {
    "_id" => p0_id,
  "alternate_name"=>nil,
  "broker_agency_contact_id"=>nil,
  "created_at"=>nil,
  "date_of_death"=>nil,
  "dob"=> Date.new(1976,2,2),
  "dob_check"=>nil,
  "employer_contact_id"=>nil,
  "encrypted_ssn"=> @ce_0['encrypted_ssn'],
  "person_relationships"=>
  [{"_id"=>BSON::ObjectId.new,
    "created_at"=>nil,
    "kind"=>"spouse",
    "updated_at"=>nil,
    "predecessor_id" => p2_id,
     "successor_id"=> p0_id, 
     "family_id" => family_id_0},
     {"_id"=>BSON::ObjectId.new,
     "created_at"=>nil,
     "kind"=>"child",
     "updated_at"=>nil,
     "predecessor_id" => p3_id,
      "successor_id"=> p0_id, 
      "family_id" => family_id_0},
      {"_id"=>BSON::ObjectId.new,
        "created_at"=>nil,
        "kind"=>"child",
        "updated_at"=>nil,
        "predecessor_id" => p4_id,
         "successor_id"=> p0_id, 
         "family_id" => family_id_0}],
  "ethnicity"=>nil,
  "first_name"=>name_0.split[0],
  "full_name"=>name_0,
  "gender"=>get_gender,
  "general_agency_contact_id"=>nil,
  "hbx_id"=>get_hbx_id,
  "is_active"=>true,
  "is_disabled"=>nil,
  "is_homeless"=>false,
  "is_incarcerated"=>nil,
  "is_physically_disabled"=>nil,
  "is_temporarily_out_of_state"=>false,
  "is_tobacco_user"=>"unknown",
  "language_code"=>nil,
  "last_name"=>name_0.split[1],
  "middle_name"=>nil,
  "modifier_id"=>nil,
  "name_pfx"=>nil,
  "name_sfx"=>nil,
  "no_dc_address"=>false,
  "no_ssn"=>nil,
  "race"=>nil,
  "tracking_version"=>1,
  "tribal_id"=>nil,
  "updated_at"=>nil,
  "updated_by"=>nil,
  "updated_by_id"=>nil,
  "user_id"=> get_hbx_id,
  "employee_roles"=>
  [{"_id"=>BSON::ObjectId('5cc6f28cec83a57a36000869'),
    "benefit_group_id"=>nil,
    "bookmark_url"=>nil,
    "census_employee_id"=>nil,
    "contact_method"=>"Paper and Electronic communications",
    "created_at"=>nil,
    "employer_profile_id"=>ep.id,
    "employment_status"=>"active",
    "hired_on"=>Date.new(2018,2,2),
    "is_active"=>true,
    "language_preference"=>"English",
    "terminated_on"=>nil,
    "updated_at"=>nil,
    "updated_by_id"=>nil}],
  "version"=>1}


  p1 = {
    "_id" =>p1_id,
    "alternate_name"=>nil,
    "broker_agency_contact_id"=>nil,
    "created_at"=>nil,
    "date_of_death"=>nil,
    "dob"=> @ce_1['dob'],
    "dob_check"=>nil,
    "employer_contact_id"=>nil,
    "encrypted_ssn"=> @ce_1['encrypted_ssn'],
    "ethnicity"=>nil,
    "first_name"=>name_1.split[0],
    "full_name"=>name_1,
    "gender"=>get_gender,
    "general_agency_contact_id"=>nil,
    "hbx_id"=>get_hbx_id,
    "is_active"=>true,
    "is_disabled"=>nil,
    "is_homeless"=>false,
    "is_incarcerated"=>nil,
    "is_physically_disabled"=>nil,
    "is_temporarily_out_of_state"=>false,
    "is_tobacco_user"=>"unknown",
    "language_code"=>nil,
    "last_name"=>name_1.split[1],
    "middle_name"=>nil,
    "modifier_id"=>nil,
    "name_pfx"=>nil,
    "name_sfx"=>nil,
    "no_dc_address"=>false,
    "no_ssn"=>nil,
    "race"=>nil,
    "tracking_version"=>1,
    "tribal_id"=>nil,
    "updated_at"=>nil,
    "updated_by"=>nil,
    "updated_by_id"=>nil,
    "user_id"=> get_hbx_id,
    "version"=>1,
    "employee_roles"=>
    [{"_id"=>BSON::ObjectId('5cc6f28cec83a57a36000869'),
      "benefit_group_id"=>nil,
      "bookmark_url"=>nil,
      "census_employee_id"=>nil,
      "contact_method"=>"Paper and Electronic communications",
      "created_at"=>nil,
      "employer_profile_id"=>ep.id,
      "employment_status"=>status,
      "hired_on"=>Date.new(2018,2,2),
      "is_active"=>true,
      "language_preference"=>"English",
      "terminated_on"=>nil,
      "updated_at"=>nil,
      "updated_by_id"=>nil}],}


  p2 = {
    "_id" => p2_id,
    "alternate_name"=>nil,
    "broker_agency_contact_id"=>nil,
    "created_at"=>nil,
    "date_of_death"=>nil,
    "dob"=> @ce_0['census_dependents'][0]['dob'],
    "dob_check"=>nil,
    "employer_contact_id"=>nil,
    "encrypted_ssn"=> @ce_0['census_dependents'][0]['encrypted_ssn'],
    "ethnicity"=>nil,
    "first_name"=>name_2.split[0],
    "full_name"=>name_2,
    "gender"=>get_gender,
    "general_agency_contact_id"=>nil,
    "hbx_id"=>get_hbx_id,
    "person_relationships"=>
    [{"_id"=>BSON::ObjectId.new,
      "created_at"=>nil,
      "kind"=>"spouse",
      "updated_at"=>nil,
      "predecessor_id" =>p2_id,
      "successor_id"=> p0_id, 
      "family_id" => family_id_0}],
    "is_active"=>true,
    "is_disabled"=>nil,
    "is_homeless"=>false,
    "is_incarcerated"=>nil,
    "is_physically_disabled"=>nil,
    "is_temporarily_out_of_state"=>false,
    "is_tobacco_user"=>"unknown",
    "language_code"=>nil,
    "last_name"=>name_2.split[1],
    "middle_name"=>nil,
    "modifier_id"=>nil,
    "name_pfx"=>nil,
    "name_sfx"=>nil,
    "no_dc_address"=>false,
    "no_ssn"=>nil,
    "race"=>nil,
    "tracking_version"=>1,
    "tribal_id"=>nil,
    "updated_at"=>nil,
    "updated_by"=>nil,
    "updated_by_id"=>nil,
    "user_id"=> get_hbx_id,
    "version"=>1}



  p3 = {
    "_id" => p3_id,
    "alternate_name"=>nil,
    "broker_agency_contact_id"=>nil,
    "created_at"=>nil,
    "date_of_death"=>nil,
    "dob"=> @ce_0['census_dependents'][1]['dob'],
    "dob_check"=>nil,
    "employer_contact_id"=>nil,
    "encrypted_ssn"=> @ce_0['census_dependents'][1]['encrypted_ssn'],
    "ethnicity"=>nil,
    "first_name"=>name_3.split[0],
    "full_name"=>name_3,
    "person_relationships"=>
    [{"_id"=>BSON::ObjectId.new,
      "created_at"=>nil,
      "kind"=>"child",
      "relative_id"=>p0_id,
      "updated_at"=>nil,
      "predecessor_id" => p3_id,
      "successor_id"=> p0_id, 
      "family_id" => family_id_0}],
    "gender"=>get_gender,
    "general_agency_contact_id"=>nil,
    "hbx_id"=>get_hbx_id,
    "is_active"=>true,
    "is_disabled"=>nil,
    "is_homeless"=>false,
    "is_incarcerated"=>nil,
    "is_physically_disabled"=>nil,
    "is_temporarily_out_of_state"=>false,
    "is_tobacco_user"=>"unknown",
    "language_code"=>nil,
    "last_name"=>name_3.split[1],
    "middle_name"=>nil,
    "modifier_id"=>nil,
    "name_pfx"=>nil,
    "name_sfx"=>nil,
    "no_dc_address"=>false,
    "no_ssn"=>nil,
    "race"=>nil,
    "tracking_version"=>1,
    "tribal_id"=>nil,
    "updated_at"=>nil,
    "updated_by"=>nil,
    "updated_by_id"=>nil,
    "user_id"=> get_hbx_id,
    "version"=>1}

  p4 = {
    "_id" => p4_id,
    "alternate_name"=>nil,
    "broker_agency_contact_id"=>nil,
    "created_at"=>nil,
    "date_of_death"=>nil,
    "dob"=> @ce_1['census_dependents'][0]['dob'],
    "dob_check"=>nil,
    "employer_contact_id"=>nil,
    "encrypted_ssn"=> @ce_1['census_dependents'][2]['encrypted_ssn'],
    "ethnicity"=>nil,
    "first_name"=>name_4.split[0],
    "full_name"=>name_4,
    "gender"=>get_gender,
    "person_relationships"=>
    [{"_id"=>BSON::ObjectId.new,
      "created_at"=>nil,
      "kind"=>"child",
      "relative_id"=>p0_id,
      "updated_at"=>nil,
      "predecessor_id" =>p4_id,
      "successor_id"=> p0_id, 
      "family_id" => family_id_0}],
    "general_agency_contact_id"=>nil,
    "hbx_id"=>get_hbx_id,
    "is_active"=>true,
    "is_disabled"=>nil,
    "is_homeless"=>false,
    "is_incarcerated"=>nil,
    "is_physically_disabled"=>nil,
    "is_temporarily_out_of_state"=>false,
    "is_tobacco_user"=>"unknown",
    "language_code"=>nil,
    "last_name"=>name_4.split[1],
    "middle_name"=>nil,
    "modifier_id"=>nil,
    "name_pfx"=>nil,
    "name_sfx"=>nil,
    "no_dc_address"=>false,
    "no_ssn"=>nil,
    "race"=>nil,
    "tracking_version"=>1,
    "tribal_id"=>nil,
    "updated_at"=>nil,
    "updated_by"=>nil,
    "updated_by_id"=>nil,
    "user_id"=> get_hbx_id,
    "version"=>1}


  @client[:people].insert_one p0
  @client[:people].insert_one p1
  @client[:people].insert_one p2
  @client[:people].insert_one p3
  @client[:people].insert_one p4


  @client[:census_members].insert_one @ce_0
  @client[:census_members].insert_one @ce_1


  family_member_id_0 = BSON::ObjectId.new
  family_member_id_1 = BSON::ObjectId.new
  family_member_id_2 = BSON::ObjectId.new
  family_member_id_3 = BSON::ObjectId.new


  family_0 = {
"_id" => family_id_0,
"application_type"=>nil,
"created_at"=>nil,
"e_case_id"=>nil,
"e_status_code"=>nil,
"family_members"=>
[{ "_id" => family_member_id_0,
"broker_role_id"=>nil,
"created_at"=>nil,
"former_family_id"=>nil,
"is_active"=>true,
"is_consent_applicant"=>false,
"is_coverage_applicant"=>true,
"is_primary_applicant"=>true,
"person_id"=> p0['_id'],
"updated_at"=>nil,
"updated_by_id"=>nil},
{ "_id" => family_member_id_1,
"broker_role_id"=>nil,
"created_at"=>nil,
"former_family_id"=>nil,
"is_active"=>true,
"is_consent_applicant"=>false,
"is_coverage_applicant"=>true,
"is_primary_applicant"=>false,
"person_id"=> p1['_id'],
"updated_at"=>nil,
"updated_by_id"=>nil},
{ "_id" => family_member_id_2,
"broker_role_id"=>nil,
"created_at"=>nil,
"former_family_id"=>nil,
"is_active"=>true,
"is_consent_applicant"=>false,
"is_coverage_applicant"=>true,
"is_primary_applicant"=>false,
"person_id"=> p2['_id'],
"updated_at"=>nil,
"updated_by_id"=>nil},
{ "_id" => family_member_id_3,
"broker_role_id"=>nil,
"created_at"=>nil,
"former_family_id"=>nil,
"is_active"=>true,
"is_consent_applicant"=>false,
"is_coverage_applicant"=>true,
"is_primary_applicant"=>false,
"person_id"=> p3['_id'],
"updated_at"=>nil,
"updated_by_id"=>nil}
],
"haven_app_id"=>nil,
"hbx_assigned_id"=>10002,
"households"=>
[{    "_id" => BSON::ObjectId.new,
"coverage_households"=>
 [{    "_id" => BSON::ObjectId.new,
   "aasm_state"=>"applicant",
   "broker_agency_id"=>nil,
   "coverage_household_members"=>
    [{    "_id" => BSON::ObjectId.new,
      "created_at"=>nil,
      "family_member_id"=> family_member_id_0,
      "is_subscriber"=>true,
      "updated_at"=>nil },
      {    "_id" => BSON::ObjectId.new,
      "created_at"=>nil,
      "family_member_id"=> family_member_id_1,
      "is_subscriber"=>false,
      "updated_at"=>nil },
      {    "_id" => BSON::ObjectId.new,
      "created_at"=>nil,
      "family_member_id"=> family_member_id_2,
      "is_subscriber"=>false,
      "updated_at"=>nil },
      {    "_id" => BSON::ObjectId.new,
      "created_at"=>nil,
      "family_member_id"=> family_member_id_3,
      "is_subscriber"=>false,
      "updated_at"=>nil }
    ],
   "created_at"=>nil,
   "is_determination_split_household"=>false,
   "is_immediate_family"=>true,
   "submitted_at"=>nil,
   "updated_at"=>nil,
   "updated_by_id"=>nil,
   "writing_agent_id"=>nil},
  {"_id"=>BSON::ObjectId.new,
   "aasm_state"=>"applicant",
   "broker_agency_id"=>nil,
   "created_at"=>nil,
   "is_determination_split_household"=>false,
   "is_immediate_family"=>false,
   "submitted_at"=>nil,
   "updated_at"=>nil,
   "updated_by_id"=>nil,
   "writing_agent_id"=>nil}],
"created_at"=>nil,
"effective_ending_on"=>Date.new(2020,5,5),
"effective_starting_on"=>Date.new(2019,5,6),
"irs_group_id"=>BSON::ObjectId.new,
"is_active"=>true,
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by_id"=>nil}],
"irs_groups"=>
[{"_id"=>BSON::ObjectId.new,
"created_at"=>nil,
"effective_ending_on"=>Date.new(2020,5,5),
"effective_starting_on"=>Date.new(2020,5,5),
"hbx_assigned_id"=>nil,
"is_active"=>true,
"updated_at"=>nil,
"updated_by_id"=>nil}],
"is_active"=>true,
"is_applying_for_assistance"=>nil,
"min_verification_due_date"=>nil,
"person_id"=>nil,
"renewal_consent_through_year"=>nil,
"status"=>"",
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by"=>nil,
"updated_by_id"=>nil,
"version"=>1,
"vlp_documents_status"=>nil}

family_1 = {
"_id" => family_id_1,
"application_type"=>nil,
"created_at"=>nil,
"e_case_id"=>nil,
"e_status_code"=>nil,
"family_members"=>
[{ "_id" => family_member_id_0,
  "broker_role_id"=>nil,
  "created_at"=>nil,
  "former_family_id"=>nil,
  "is_active"=>true,
  "is_consent_applicant"=>false,
  "is_coverage_applicant"=>true,
  "is_primary_applicant"=>true,
  "person_id"=> p1['_id'],
  "updated_at"=>nil,
  "updated_by_id"=>nil}
],
"haven_app_id"=>nil,
"hbx_assigned_id"=>10002,
"households"=>
[{    "_id" => BSON::ObjectId.new,
  "coverage_households"=>
   [{    "_id" => BSON::ObjectId.new,
     "aasm_state"=>"applicant",
     "broker_agency_id"=>nil,
     "coverage_household_members"=>
      [{    "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "family_member_id"=> family_member_id_0,
        "is_subscriber"=>true,
        "updated_at"=>nil },
        {    "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "family_member_id"=> family_member_id_1,
        "is_subscriber"=>false,
        "updated_at"=>nil },
        {    "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "family_member_id"=> family_member_id_2,
        "is_subscriber"=>false,
        "updated_at"=>nil },
        {    "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "family_member_id"=> family_member_id_3,
        "is_subscriber"=>false,
        "updated_at"=>nil }
      ],
     "created_at"=>nil,
     "is_determination_split_household"=>false,
     "is_immediate_family"=>true,
     "submitted_at"=>nil,
     "updated_at"=>nil,
     "updated_by_id"=>nil,
     "writing_agent_id"=>nil},
    {"_id"=>BSON::ObjectId.new,
     "aasm_state"=>"applicant",
     "broker_agency_id"=>nil,
     "created_at"=>nil,
     "is_determination_split_household"=>false,
     "is_immediate_family"=>false,
     "submitted_at"=>nil,
     "updated_at"=>nil,
     "updated_by_id"=>nil,
     "writing_agent_id"=>nil}],
  "created_at"=>nil,
  "effective_ending_on"=>Date.new(2020,5,5),
  "effective_starting_on"=>Date.new(2019,5,6),
  "irs_group_id"=>BSON::ObjectId.new,
  "is_active"=>true,
  "submitted_at"=>nil,
  "updated_at"=>nil,
  "updated_by_id"=>nil}],
"irs_groups"=>
[{"_id"=>BSON::ObjectId.new,
  "created_at"=>nil,
  "effective_ending_on"=>Date.new(2020,5,5),
  "effective_starting_on"=>Date.new(2020,5,5),
  "hbx_assigned_id"=>nil,
  "is_active"=>true,
  "updated_at"=>nil,
  "updated_by_id"=>nil}],
"is_active"=>true,
"is_applying_for_assistance"=>nil,
"min_verification_due_date"=>nil,
"person_id"=>nil,
"renewal_consent_through_year"=>nil,
"status"=>"",
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by"=>nil,
"updated_by_id"=>nil,
"version"=>1,
"vlp_documents_status"=>nil}


@client[:families].insert_one family_0
@client[:families].insert_one family_1

  end


  def solo(ep,age,name_0,name_1,family_id_0,family_id_1,status) 
    family_member_id_0 = BSON::ObjectId.new
    family_member_id_1 = BSON::ObjectId.new
    @ce_0 = {"_id" => BSON::ObjectId.new,
      "_type" => 'census_employee',
      "aasm_state"=>"eligible",
      "autocomplete"=> nil,
      "cobra_begin_date"=>nil,
      "coverage_terminated_on"=>nil,
      "created_at"=>nil,
      "dob"=> age,
      "email"=>
      { "_id" => BSON::ObjectId.new,
        "address"=>"dan.thomas@dc.gov",
        "created_at"=>nil,
        "kind"=>"work",
        "updated_at"=>nil},
      "employee_relationship"=>"employee",
      "employee_role_id"=>nil,
      "employer_assigned_family_id"=>nil,
      "employer_profile_id"=>ep.id,
      "employment_terminated_on"=>nil,
      "encrypted_ssn"=> get_ssn,
      "gender"=>"male",
      "first_name"=> name_0.split[0],
      "hired_on"=>Time.new("2017,04,03"),
      "is_business_owner"=>true,
      "last_name"=>name_0.split[1],
      "middle_name"=>nil,
      "name_sfx"=>nil,
      "no_ssn_allowed"=>false,
      "updated_at"=>nil}

      @ce_1 = {"_id" => BSON::ObjectId.new,
        "_type" => 'census_employee',
        "aasm_state"=>"eligible",
        "autocomplete"=> nil,
        "cobra_begin_date"=>nil,
        "coverage_terminated_on"=>young,
        "created_at"=>nil,
        "dob"=>old,
        "email"=>
        { "_id" => BSON::ObjectId.new,
          "address"=>"dan.thomas@dc.gov",
          "created_at"=>nil,
          "kind"=>"work",
          "updated_at"=>nil},
        "employee_relationship"=>"employee",
        "employee_role_id"=>nil,
        "employer_assigned_family_id"=>nil,
        "employer_profile_id"=>ep.id,
        "employment_terminated_on"=>nil,
        "encrypted_ssn"=> get_ssn,
        "first_name"=>name_1.split[0],
        "gender"=>"male",
        "hired_on"=>Time.new("2017,04,03"),
        "is_business_owner"=>true,
        "last_name"=>name_1.split[1],
        "middle_name"=>nil,
        "name_sfx"=>nil,
        "no_ssn_allowed"=>false,
        "updated_at"=>nil}

  p0_id =  BSON::ObjectId.new
  p1_id = BSON::ObjectId.new

  p0 = {
    "_id" => p0_id,
  "alternate_name"=>nil,
  "broker_agency_contact_id"=>nil,
  "created_at"=>nil,
  "date_of_death"=>nil,
  "dob"=> Date.new(1976,2,2),
  "dob_check"=>nil,
  "employer_contact_id"=>nil,
  "encrypted_ssn"=> @ce_0['encrypted_ssn'],
  "ethnicity"=>nil,
  "first_name"=>name_0.split[0],
  "full_name"=>name_0,
  "gender"=>get_gender,
  "general_agency_contact_id"=>nil,
  "hbx_id"=>get_hbx_id,
  "is_active"=>true,
  "is_disabled"=>nil,
  "is_homeless"=>false,
  "is_incarcerated"=>nil,
  "is_physically_disabled"=>nil,
  "is_temporarily_out_of_state"=>false,
  "is_tobacco_user"=>"unknown",
  "language_code"=>nil,
  "last_name"=>name_0.split[1],
  "middle_name"=>nil,
  "modifier_id"=>nil,
  "name_pfx"=>nil,
  "name_sfx"=>nil,
  "no_dc_address"=>false,
  "no_ssn"=>nil,
  "race"=>nil,
  "tracking_version"=>1,
  "tribal_id"=>nil,
  "updated_at"=>nil,
  "updated_by"=>nil,
  "updated_by_id"=>nil,
  "user_id"=> get_hbx_id,
  "employee_roles"=>
  [{"_id"=>BSON::ObjectId('5cc6f28cec83a57a36000869'),
    "benefit_group_id"=>nil,
    "bookmark_url"=>nil,
    "census_employee_id"=>nil,
    "contact_method"=>"Paper and Electronic communications",
    "created_at"=>nil,
    "employer_profile_id"=>ep.id,
    "employment_status"=>"active",
    "hired_on"=>Date.new(2018,2,2),
    "is_active"=>true,
    "language_preference"=>"English",
    "terminated_on"=>nil,
    "updated_at"=>nil,
    "updated_by_id"=>nil}],
  "version"=>1}


  p1 = {
    "_id" =>p1_id,
    "alternate_name"=>nil,
    "broker_agency_contact_id"=>nil,
    "created_at"=>nil,
    "date_of_death"=>nil,
    "dob"=> @ce_1['dob'],
    "dob_check"=>nil,
    "employer_contact_id"=>nil,
    "encrypted_ssn"=> @ce_1['encrypted_ssn'],
    "ethnicity"=>nil,
    "first_name"=>name_1.split[0],
    "full_name"=>name_1,
    "gender"=>get_gender,
    "general_agency_contact_id"=>nil,
    "hbx_id"=>get_hbx_id,
    "is_active"=>true,
    "is_disabled"=>nil,
    "is_homeless"=>false,
    "is_incarcerated"=>nil,
    "is_physically_disabled"=>nil,
    "is_temporarily_out_of_state"=>false,
    "is_tobacco_user"=>"unknown",
    "language_code"=>nil,
    "last_name"=>name_1.split[1],
    "middle_name"=>nil,
    "modifier_id"=>nil,
    "name_pfx"=>nil,
    "name_sfx"=>nil,
    "no_dc_address"=>false,
    "no_ssn"=>nil,
    "race"=>nil,
    "tracking_version"=>1,
    "tribal_id"=>nil,
    "updated_at"=>nil,
    "updated_by"=>nil,
    "updated_by_id"=>nil,
    "user_id"=> get_hbx_id,
    "version"=>1,
    "employee_roles"=>
    [{"_id"=>BSON::ObjectId('5cc6f28cec83a57a36000869'),
      "benefit_group_id"=>nil,
      "bookmark_url"=>nil,
      "census_employee_id"=>nil,
      "contact_method"=>"Paper and Electronic communications",
      "created_at"=>nil,
      "employer_profile_id"=> ep.id,
      "employment_status"=>status,
      "hired_on"=>Date.new(2018,2,2),
      "is_active"=>true,
      "language_preference"=>"English",
      "terminated_on"=>nil,
      "updated_at"=>nil,
      "updated_by_id"=>nil}],}




  @client[:people].insert_one p0
  @client[:people].insert_one p1


  @client[:census_members].insert_one @ce_0
  @client[:census_members].insert_one @ce_1


  family_member_id_0 = BSON::ObjectId.new
  family_member_id_1 = BSON::ObjectId.new
  family_member_id_2 = BSON::ObjectId.new


  family_0 = {
"_id" => family_id_0,
"application_type"=>nil,
"created_at"=>nil,
"e_case_id"=>nil,
"e_status_code"=>nil,
"family_members"=>
[{ "_id" => family_member_id_0,
"broker_role_id"=>nil,
"created_at"=>nil,
"former_family_id"=>nil,
"is_active"=>true,
"is_consent_applicant"=>false,
"is_coverage_applicant"=>true,
"is_primary_applicant"=>true,
"person_id"=> p0['_id'],
"updated_at"=>nil,
"updated_by_id"=>nil}
],
"haven_app_id"=>nil,
"hbx_assigned_id"=>10002,
"households"=>
[{    "_id" => BSON::ObjectId.new,
"coverage_households"=>
 [{    "_id" => BSON::ObjectId.new,
   "aasm_state"=>"applicant",
   "broker_agency_id"=>nil,
   "coverage_household_members"=>
    [{    "_id" => BSON::ObjectId.new,
      "created_at"=>nil,
      "family_member_id"=> family_member_id_0,
      "is_subscriber"=>true,
      "updated_at"=>nil }
    ],
   "created_at"=>nil,
   "is_determination_split_household"=>false,
   "is_immediate_family"=>true,
   "submitted_at"=>nil,
   "updated_at"=>nil,
   "updated_by_id"=>nil,
   "writing_agent_id"=>nil},
  {"_id"=>BSON::ObjectId.new,
   "aasm_state"=>"applicant",
   "broker_agency_id"=>nil,
   "created_at"=>nil,
   "is_determination_split_household"=>false,
   "is_immediate_family"=>false,
   "submitted_at"=>nil,
   "updated_at"=>nil,
   "updated_by_id"=>nil,
   "writing_agent_id"=>nil}],
"created_at"=>nil,
"effective_ending_on"=>Date.new(2020,5,5),
"effective_starting_on"=>Date.new(2019,5,6),
"irs_group_id"=>BSON::ObjectId.new,
"is_active"=>true,
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by_id"=>nil}],
"irs_groups"=>
[{"_id"=>BSON::ObjectId.new,
"created_at"=>nil,
"effective_ending_on"=>Date.new(2020,5,5),
"effective_starting_on"=>Date.new(2020,5,5),
"hbx_assigned_id"=>nil,
"is_active"=>true,
"updated_at"=>nil,
"updated_by_id"=>nil}],
"is_active"=>true,
"is_applying_for_assistance"=>nil,
"min_verification_due_date"=>nil,
"person_id"=>nil,
"renewal_consent_through_year"=>nil,
"status"=>"",
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by"=>nil,
"updated_by_id"=>nil,
"version"=>1,
"vlp_documents_status"=>nil}

family_1 = {
"_id" => family_id_1,
"application_type"=>nil,
"created_at"=>nil,
"e_case_id"=>nil,
"e_status_code"=>nil,
"family_members"=>
[{ "_id" => family_member_id_1,
  "broker_role_id"=>nil,
  "created_at"=>nil,
  "former_family_id"=>nil,
  "is_active"=>true,
  "is_consent_applicant"=>false,
  "is_coverage_applicant"=>true,
  "is_primary_applicant"=>true,
  "person_id"=> p1['_id'],
  "updated_at"=>nil,
  "updated_by_id"=>nil}

],
"haven_app_id"=>nil,
"hbx_assigned_id"=>10002,
"households"=>
[{    "_id" => BSON::ObjectId.new,
  "coverage_households"=>
   [{    "_id" => BSON::ObjectId.new,
     "aasm_state"=>"applicant",
     "broker_agency_id"=>nil,
     "coverage_household_members"=>
      [{    "_id" => BSON::ObjectId.new,
        "created_at"=>nil,
        "family_member_id"=> family_member_id_0,
        "is_subscriber"=>true,
        "updated_at"=>nil }

      ],
     "created_at"=>nil,
     "is_determination_split_household"=>false,
     "is_immediate_family"=>true,
     "submitted_at"=>nil,
     "updated_at"=>nil,
     "updated_by_id"=>nil,
     "writing_agent_id"=>nil},
    {"_id"=>BSON::ObjectId.new,
     "aasm_state"=>"applicant",
     "broker_agency_id"=>nil,
     "created_at"=>nil,
     "is_determination_split_household"=>false,
     "is_immediate_family"=>false,
     "submitted_at"=>nil,
     "updated_at"=>nil,
     "updated_by_id"=>nil,
     "writing_agent_id"=>nil}],
  "created_at"=>nil,
  "effective_ending_on"=>Date.new(2020,5,5),
  "effective_starting_on"=>Date.new(2019,5,6),
  "irs_group_id"=>BSON::ObjectId.new,
  "is_active"=>true,
  "submitted_at"=>nil,
  "updated_at"=>nil,
  "updated_by_id"=>nil}],
"irs_groups"=>
[{"_id"=>BSON::ObjectId.new,
  "created_at"=>nil,
  "effective_ending_on"=>Date.new(2020,5,5),
  "effective_starting_on"=>Date.new(2020,5,5),
  "hbx_assigned_id"=>nil,
  "is_active"=>true,
  "updated_at"=>nil,
  "updated_by_id"=>nil}],
"is_active"=>true,
"is_applying_for_assistance"=>nil,
"min_verification_due_date"=>nil,
"person_id"=>nil,
"renewal_consent_through_year"=>nil,
"status"=>"",
"submitted_at"=>nil,
"updated_at"=>nil,
"updated_by"=>nil,
"updated_by_id"=>nil,
"version"=>1,
"vlp_documents_status"=>nil}
  

    @client[:families].insert_one family_0
    @client[:families].insert_one family_1

  end

  def db_dump
    @people = @people.map { |person| { insert_one: person } }
    @client[:people].insert_many @people
    @families = @families.map { |family| { insert_one: family } }
    @client[:families].insert_many @families
    @ces = @ces.map { |ce| { insert_one: ce } }
    @client[:census_members].insert_many @ces
    @people = []
    @families = []
    @ces = []
  end




  def build_people
  Mongo::Logger.logger.level = ::Logger::FATAL
    puts "********************************* Opm person seed started at #{Time.now} ********************************* "
    @counter = 0
      @sampler = 0
      
    CSV.foreach("db/seedfiles/opm_people.csv", :headers => true).with_index(1)  do |row,ln|
      org = Organization.where(dba: @agency_codes[row[0]][0]).first
      ep =  org.employer_profile
      age = @age_codes[row[2]]
      name_0 = Faker::Name.name
      name_1 = Faker::Name.name
      name_2 = Faker::Name.name
      name_3 = Faker::Name.name
      name_4 = Faker::Name.name
      name_5 = Faker::Name.name
      name_6 = Faker::Name.name
      name_7 = Faker::Name.name
      name_8 = Faker::Name.name
      name_9 = Faker::Name.name
      family_id_0 = BSON::ObjectId.new
      family_id_1 = BSON::ObjectId.new
      family_id_2 = BSON::ObjectId.new
      family_id_3 = BSON::ObjectId.new

      if @counter == 0
        if @sampler == 0 
          spouse_and_kid(ep,age,name_0,name_1,name_2,name_3,family_id_0,family_id_1, "active")
          spouse_and_kid(ep,age,name_4,name_5,name_6,name_7,family_id_2,family_id_3, "retired")
         @sampler = 1
        else 
          big_fam(ep,age,name_8,name_9,name_0,name_1,name_2,family_id_0,family_id_1,"active")
          big_fam(ep,age,name_3,name_4,name_5,name_6,name_7,family_id_2,family_id_3, "retired")
         @sampler = 0 
        end
        if @people.count >= 99 
          db_dump
        end
         @counter  = 1
      elsif @counter == 1 
          spouse_only(ep,age,name_8,name_9,name_0,family_id_2,family_id_3,"active") 
          spouse_only(ep,age,name_1,name_2,name_3,family_id_0,family_id_1,"retired") 
          if @people.count >= 99 
            db_dump
          end
        @counter = 2
      elsif @counter == 2
          solo(ep,age,name_4,name_5,family_id_0,family_id_1,"active") 
          solo(ep,age,name_6,name_7,family_id_2,family_id_3,"retired") 
          if @people.count >= 99 
            db_dump
          end
        @counter = 0
        end
      end

      puts "********************************* OPM person seed completed at #{Time.now} ********************************* "
      
    end
  end

    seed = OpmSeed.new
    
    seed.build_orgs 
    seed.build_people


# Organization.all.each do |org|
#     org.update_attributes(hbx_id: HbxIdGenerator.generate_organization_id)
# end