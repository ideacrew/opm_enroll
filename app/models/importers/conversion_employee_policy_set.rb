module Importers
  class ConversionEmployeePolicySet
    def headers
      [
        "Action",
        "Type of Enrollment",
        "Market",
        "Sponsor Name",
        "FEIN",
        "Broker Name",
        "Broker NPN",
        "Hire Date",
        "Benefit Begin Date",
        "Plan Name",
        "QHP Id (ignore)",
        "CSR Info (ignore)",
        "CSR Variant (ignore)",
        "HIOS Id",
        "(AUTO) Premium Total",
        "Employer Contribution",
        "(AUTO) Employee Responsible Amt",
        "Subscriber SSN",
        "Subscriber DOB",
        "Subscriber Gender",
        "Subscriber Premium",
        "Subscriber First Name",
        "Subscriber Middle Name",
        "Subscriber Last Name",
        "Subscriber Email",
        "Subscriber Phone",
        "Subscriber Address 1",
        "Subscriber Address 2",
        "Subscriber City",
        "Subscriber State",
        "Subscriber Zip",
        "SELF (only one option)",
        "Dep1 SSN",
        "Dep1 DOB",
        "Dep1 Gender",
        "Dep1 Premium",
        "Dep1 First Name",
        "Dep1 Middle Name",
        "Dep1 Last Name",
        "Dep1 Email",
        "Dep1 Phone",
        "Dep1 Address 1",
        "Dep1 Address 2",
        "Dep1 City",
        "Dep1 State",
        "Dep1 Zip",
        "Dep1 Relationship",
        "Dep2 SSN",
        "Dep2 DOB",
        "Dep2 Gender",
        "Dep2 Premium",
        "Dep2 First Name",
        "Dep2 Middle Name",
        "Dep2 Last Name",
        "Dep2 Email",
        "Dep2 Phone",
        "Dep2 Address 1",
        "Dep2 Address 2",
        "Dep2 City",
        "Dep2 State",
        "Dep2 Zip",
        "Dep2 Relationship",
        "Dep3 SSN",
        "Dep3 DOB",
        "Dep3 Gender",
        "Dep3 Premium",
        "Dep3 First Name",
        "Dep3 Middle Name",
        "Dep3 Last Name",
        "Dep3 Email",
        "Dep3 Phone",
        "Dep3 Address 1",
        "Dep3 Address 2",
        "Dep3 City",
        "Dep3 State",
        "Dep3 Zip",
        "Dep3 Relationship",
        "Dep4 SSN",
        "Dep4 DOB",
        "Dep4 Gender",
        "Dep4 Premium",
        "Dep4 First Name",
        "Dep4 Middle Name",
        "Dep4 Last Name",
        "Dep4 Email",
        "Dep4 Phone",
        "Dep4 Address 1",
        "Dep4 Address 2",
        "Dep4 City",
        "Dep4 State",
        "Dep4 Zip",
        "Dep4 Relationship",
        "Dep5 SSN",
        "Dep5 DOB",
        "Dep5 Gender",
        "Dep5 Premium",
        "Dep5 First Name",
        "Dep5 Middle Name",
        "Dep5 Last Name",
        "Dep5 Email",
        "Dep5 Phone",
        "Dep5 Address 1",
        "Dep5 Address 2",
        "Dep5 City",
        "Dep5 State",
        "Dep5 Zip",
        "Dep5 Relationship",
        "Dep6 SSN",
        "Dep6 DOB",
        "Dep6 Gender",
        "Dep6 Premium",
        "Dep6 First Name",
        "Dep6 Middle Name",
        "Dep6 Last Name",
        "Dep6 Email",
        "Dep6 Phone",
        "Dep6 Address 1",
        "Dep6 Address 2",
        "Dep6 City",
        "Dep6 State",
        "Dep6 Zip",
        "Dep6 Relationship",
        "Dep7 SSN",
        "Dep7 DOB",
        "Dep7 Gender",
        "Dep7 Premium",
        "Dep7 First Name",
        "Dep7 Middle Name",
        "Dep7 Last Name",
        "Dep7 Email",
        "Dep7 Phone",
        "Dep7 Address 1",
        "Dep7 Address 2",
        "Dep7 City",
        "Dep7 State",
        "Dep7 Zip",
        "Dep7 Relationship",
        "Dep8 SSN",
        "Dep8 DOB",
        "Dep8 Gender",
        "Dep8 Premium",
        "Dep8 First Name",
        "Dep8 Middle Name",
        "Dep8 Last Name",
        "Dep8 Email",
        "Dep8 Phone",
        "Dep8 Address 1",
        "Dep8 Address 2",
        "Dep8 City",
        "Dep8 State",
        "Dep8 Zip",
        "Dep8 Relationship",
        "Import Status",
        "Import Details"
      ]
    end

    def row_mapping
      [
      :action,
      :ignore,
      :ignore,
      :ignore,
      :fein,
      :ignore,
      :ignore,
      :ignore,
      :benefit_begin_date,
      :ignore,
      :ignore,
      :ignore,
      :ignore,
      :hios_id,
      :ignore,
      :ignore,
      :ignore,
      :subscriber_ssn,
      :subscriber_dob
    ]
    end

    include ::Importers::RowSet

    def initialize(file_name, o_stream, default_policy_start, py)
      @default_policy_start = default_policy_start
      @plan_year = py
      @spreadsheet = Roo::Spreadsheet.open(file_name)
      @out_stream = o_stream
      @out_csv = CSV.new(o_stream)
    end

    def create_model(record_attrs)
      the_action = record_attrs["action"].blank? ? "add" : records_attrs["action"].to_s.strip.downcase
      case the_action
      when "update"
        ::Importers::ConversionEmployeePolicyUpdate.new(record_attrs.merge({:default_policy_start => @default_policy_start, :plan_year => @plan_year}))
      else
        ::Importers::ConversionEmployeePolicy.new(record_attrs.merge({:default_policy_start => @default_policy_start, :plan_year => @plan_year}))
      end
    end
  end
end
