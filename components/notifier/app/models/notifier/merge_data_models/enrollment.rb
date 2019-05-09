module Notifier
  class MergeDataModels::Enrollment
    include Virtus.model
    include ActionView::Helpers::NumberHelper

    attribute :coverage_start_on, String
    attribute :plan_name, String
    attribute :employee_responsible_amount, String
    attribute :employer_responsible_amount, String
    attribute :premium_amount, String
    attribute :subscriber, MergeDataModels::Person
    attribute :dependents, Array[MergeDataModels::Person]
    attribute :employee_first_name, String
    attribute :employee_last_name, String
    attribute :coverage_end_on, String
    attribute :enrolled_count, String
    attribute :enrollment_kind, String
    # attribute :metal_level, String
    attribute :coverage_kind, String
    # attribute :plan_carrier, String
    attribute :coverage_end_on_minus_60_days, String
    attribute :coverage_end_on_plus_60_days, String

    def self.stubbed_object
      end_on = TimeKeeper.date_of_record.end_of_month
      enrollment = Notifier::MergeDataModels::Enrollment.new({
        coverage_start_on: TimeKeeper.date_of_record.next.beginning_of_month.strftime('%m/%d/%Y'),
        coverage_end_on: TimeKeeper.date_of_record.end_of_month.strftime('%m/%d/%Y'),
        plan_name: 'Aetna GOLD',
        employer_responsible_amount: '$250.00',
        employee_responsible_amount: '$90.00',
        premium_amount: '340.00',
        enrolled_count: '2',
        enrollment_kind: "special_enrollment",
        employee_first_name: 'David',
        employee_last_name: 'Finch',
        coverage_kind: 'health',
        coverage_end_on_minus_60_days: ((end_on - 60.days).strftime('%m/%d/%Y')),
        coverage_end_on_plus_60_days: ((end_on + 60.days).strftime('%m/%d/%Y'))
      })

      enrollment.subscriber = Notifier::MergeDataModels::Person.stubbed_object
      enrollment.dependents = [Notifier::MergeDataModels::Person.stubbed_object]
      enrollment
    end

    def self.stubbed_object_dental
      end_on = TimeKeeper.date_of_record.end_of_month
      enrollment = Notifier::MergeDataModels::Enrollment.new({
        coverage_start_on: TimeKeeper.date_of_record.next.beginning_of_month.strftime('%m/%d/%Y'),
        coverage_end_on: TimeKeeper.date_of_record.end_of_month.strftime('%m/%d/%Y'),
        plan_name: 'Delta Dental',
        employer_responsible_amount: '$25.00',
        employee_responsible_amount: '$9.00',
        premium_amount: '34.00',
        enrolled_count: '2',
        employee_first_name: 'David',
        employee_last_name: 'Finch',
        coverage_end_on_minus_60_days: ((end_on - 60.days).strftime('%m/%d/%Y')),
        coverage_end_on_plus_60_days: ((end_on + 60.days).strftime('%m/%d/%Y'))
      })

      enrollment.subscriber = Notifier::MergeDataModels::Person.stubbed_object
      enrollment.dependents = [Notifier::MergeDataModels::Person.stubbed_object]
      enrollment
    end

    def employer_cost
      number_to_currency(employer_responsible_amount.to_f)
    end

    def employee_cost
      number_to_currency(employee_responsible_amount.to_f)
    end

    def premium
      number_to_currency(premium_amount.to_f)
    end

    def number_of_enrolled
      dependents.count + 1
    end
  end
end