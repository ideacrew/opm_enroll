module Notifier
  module Services
    class IndividualNoticeService

      def recipients
        {
          "Consumer" => "Notifier::MergeDataModels::ConsumerRole"
        }
      end

      def setting_placeholders
        system_settings.inject([]) do |placeholders, (category, attribute_set)|
          attribute_set.each do |attribute|
            placeholders << {
              title: "#{category.to_s.humanize}: #{attribute.humanize}",
              target: ["Settings", category, attribute].join('.')
            }
          end
          placeholders
        end
      end

      def system_settings
        {
          :site => %w(domain_name home_url help_url faqs_url main_web_address short_name byline long_name short_url shop_find_your_doctor_url document_verification_checklist_url registration_path),
          :contact_center => %w(name alt_name phone_number short_number fax tty_number alt_phone_number email_address small_business_email appeals),
          :'contact_center.mailing_address' => %w(name address_1 address_2 city state zip_code),
          :aca => %w(state_name state_abbreviation),
        }
      end
    end
  end
end