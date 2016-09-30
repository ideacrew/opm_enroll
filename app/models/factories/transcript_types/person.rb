module Factories
  module TranscriptTypes
    class PersonError < StandardError; end

    class Person < Factories::TranscriptTypes::Base


      def self.associations
        [
         "user",
         "responsible_party",
         "person_relationships",
         "addresses",
         "phones",
         "emails"
       ]
      end

      def initialize
        super
      end

      def find_or_build(person)
        @transcript[:other] = person

        people = match_instance(person)

        case people.count
        when 0
          @transcript[:source_is_new] = true
          @transcript[:source] = initialize_person
        when 1
          @transcript[:source_is_new] = false
          @transcript[:source] = people.first
        else
          message = "Ambiguous person match: more than one person matches criteria"
          raise Factories::TranscriptTypes::PersonError message
        end

        compare_instance
        validate_instance
      end

      private

      def match_instance(person)

        if person.hbx_id.present?
          matched_people = ::Person.where(hbx_id: person.hbx_id) || []
        else
          matched_people = ::Person.match_by_id_info(
              ssn: person.ssn,
              dob: person.dob,
              last_name: person.last_name,
              first_name: person.first_name
            )
        end
        matched_people
      end

      def initialize_person
        fields = ::Person.new.fields.inject({}){|data, (key, val)| data[key] = val.default_val; data }
        fields.delete_if{|key,_| @fields_to_ignore.include?(key)}
        ::Person.new(fields)
      end
    end
  end
end
