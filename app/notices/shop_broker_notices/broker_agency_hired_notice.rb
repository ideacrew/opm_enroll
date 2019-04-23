class ShopBrokerNotices::BrokerAgencyHiredNotice < ShopBrokerNotice

  Required= Notice::Required + []

  attr_accessor :broker_agency_profile
  attr_accessor :employer_profile

  def initialize(employer_profile, args = {})
    self.employer_profile = employer_profile
    self.broker_agency_profile = employer_profile.broker_agency_profile
    args[:recipient] = broker_agency_profile
    args[:market_kind]= 'shop'
    args[:notice] = PdfTemplates::BrokerNotice.new
    args[:to] = broker_agency_profile.primary_broker_role.email_address
    args[:name] = broker_agency_profile.primary_broker_role.person.full_name
    args[:recipient_document_store] = broker_agency_profile
    self.header = "notices/shared/shop_header.html.erb"
    super(employer_profile, args)
  end

  def deliver
    build
    generate_pdf_notice
    non_discrimination_attachment
    attach_envelope
    upload_and_send_secure_message
  end

  def build
    notice.primary_fullname = broker_agency_profile.legal_name
    notice.mpi_indicator = self.mpi_indicator
    notice.broker = PdfTemplates::Broker.new({
      full_name: broker_agency_profile.primary_broker_role.person.full_name.titleize,
      assignment_date: employer_profile.broker_agency_accounts.detect{|br| br.is_active == true}.start_on
    })
    notice.employer_name = employer_profile.legal_name.titleize
    notice.employer = PdfTemplates::EmployerStaff.new({
      employer_first_name: employer_profile.staff_roles.first.first_name,
      employer_phone: employer_profile.staff_roles.first.work_phone_or_best,
      employer_last_name: employer_profile.staff_roles.first.last_name,
      employer_email: employer_profile.staff_roles.first.work_email_or_best,

    })
    notice.broker_agency = broker_agency_profile.legal_name.titleize
    address = broker_agency_profile.organization.primary_mailing_address.present? ? broker_agency_profile.organization.primary_mailing_address : broker_agency_profile.organization.primary_office_location.address
    append_address(address)
    append_hbe
  end
end