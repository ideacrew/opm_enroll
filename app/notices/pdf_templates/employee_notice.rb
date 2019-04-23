module PdfTemplates
  class EmployeeNotice
    include Virtus.model

    attribute :notification_type, String
    attribute :subject, String
    attribute :first_name, String
    attribute :last_name, String
    attribute :primary_fullname, String
    attribute :primary_identifier, String
    attribute :mpi_indicator, String
    attribute :primary_address, PdfTemplates::NoticeAddress
    attribute :census_employee, PdfTemplates::CensusEmployee
    attribute :employer_name, String
    attribute :employer_full_name, String
    attribute :primary_email, String
    attribute :broker, PdfTemplates::Broker
    attribute :hbe, PdfTemplates::Hbe
    attribute :plan, PdfTemplates::Plan
    attribute :dental_plan, PdfTemplates::Plan
    attribute :census_employee, PdfTemplates::CensusEmployee
    attribute :enrollment, PdfTemplates::Enrollment
    attribute :dental_enrollment, PdfTemplates::Enrollment
    attribute :email, String
    attribute :primary_email, String
    attribute :plan_year, PdfTemplates::PlanYear
    attribute :sep, PdfTemplates::SpecialEnrollmentPeriod
    attribute :qle, PdfTemplates::QualifyingLifeEventKind

    def shop?
      return true
    end

    def broker?
      return false
    end

    def employee_notice?
      return true
    end

    def general_agency?
      false
    end
  end
end