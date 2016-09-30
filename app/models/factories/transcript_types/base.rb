module Factories
  module TranscriptTypes
    class Base

      attr_reader :transcript, :fields_to_ignore, :associations

      def initialize(options = {})
        @transcript = options
        @transcript = transcript_template
        @fields_to_ignore ||= ['_id', 'version', 'created_at', 'updated_at', 'encrypted_ssn']
      end

      def match_instance
        raise StandardError "Implement this method in child class"
      end

      def build_instance
        raise StandardError "Implement this method in child class"
      end

      def compare_instance
        return unless @transcript[:other].present?
        return if @transcript[:source_is_new]

        differences     = HashWithIndifferentAccess.new
        base_record    = @transcript[:source]

        differences[:base] = key_comparision
        self.class.associations.each do |association|
          differences[association] = key_comparision(association)
        end

        @transcript[:compare] = differences
      end

      def key_comparision(assoc =nil)
        differences     = HashWithIndifferentAccess.new

        if assoc.present?
          base_record = (@transcript[:source].send(assoc).is_a?(Array) ? @transcript[:source].send(assoc).first : @transcript[:source].send(assoc))
          compare_record = (@transcript[:other].send(assoc).is_a?(Array) ? @transcript[:other].send(assoc).first : @transcript[:other].send(assoc)) 
        else
          base_record     = @transcript[:source]
          compare_record  = @transcript[:other]
        end
     
        if base_record.present? && compare_record.present?
          all_keys = base_record.attribute_names.reject{|attr| @fields_to_ignore.include?(attr)}

          all_keys.each do |k|
            next if base_record[k].blank? && compare_record[k].blank?

            if base_record[k].blank?
              differences[:add] ||= {}
              differences[:add][k] = compare_record[k]
            elsif compare_record[k].blank?
              differences[:remove] ||= {}
              differences[:remove][k] = base_record[k]
            elsif base_record[k].is_a?(Array) && compare_record[k].is_a?(Array)
              differences[:array] ||= {}
              old_values = base_record[k] - compare_record[k]
              new_values = compare_record[k] - base_record[k]
              differences[:array][k] = { add: new_values, remove: old_values }.delete_if { |_, vv| vv.blank? }
              differences[:array][k].blank? ? differences = {} : differences[:array]
            else
              if base_record[k] != compare_record[k]
                differences[:update] ||= {}
                differences[:update][k] = compare_record[k]
              end
            end
          end
        end
        differences
      end

      def validate_instance
        return
        @transcript[:source].is_valid?
        @transcript[:other].is_valid?
        @transcript[:source_errors] = @transcript[:source].errors
        @transcript[:other_errors] = @transcript[:other].errors
      end

      # Return model instance using the transcript hash table values
      def to_model
      end

      def copy_properties(from, to, properties)
        properties.each { |property| copy_property(from, to, property) }
      end

      def copy_property(from, to, property)
        to.send("#{property}=", from.send(property))
      end

      # Hash table for managing transcript factory data
      def transcript_template
        {
          # Local data set values
          source:         HashWithIndifferentAccess.new,
          # External data set values 
          other:          HashWithIndifferentAccess.new,
          # Result of comparing values of the "source" and "other" content
          compare:        HashWithIndifferentAccess.new,
          # Functional errors in the "source" data set
          source_errors:  HashWithIndifferentAccess.new,
          # Functional errors in the "other" data set
          other_errors:   HashWithIndifferentAccess.new,
          # "source" data set was generated from the "other" data set values?
          source_is_new:  false,
        }
      end

      def instance_with_all_attributes(class_name)
        klass.classify.constantize
        fields = klass.new.fields.inject({}){|data, (key, val)| data[key] = val.default_val; data }
        fields.delete_if{|key,_| @fields_to_ignore.include?(key)}
        klass.new(fields)
      end

      def family_transcript_prototype
        person = Person.new.fields.keys
        consumer_role = ConsumerRole.new.fields.keys
        person.consumer_role = consumer_role

        family = Family.new.fields.keys
        family.primary_family_member = person
        family.latest_household.hbx_enrollments << HbxEnrollment.new.fields.keys

        { family: family.attributes.merge({
          family_members: [
            family_member: family.family_members.first.attributes
            ],
            irs_groups: [
              irs_group: family.irs_groups.first.attributes
              ],
              households: [
                household: family.households.first.attributes.merge({
                  hbx_enrollments: [
                    hbx_enrollment: family.households.first.hbx_enrollments.first.attributes
                  ]
                  })
              ]
              }),
        people: [
          person: person.attributes.merge({
            consumer_role: person.consumer_role.attributes
            })
          ] }
      end
    end
  end
end
