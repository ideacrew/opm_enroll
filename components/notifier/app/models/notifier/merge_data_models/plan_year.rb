module Notifier
  class MergeDataModels::PlanYear
    include Virtus.model

    attribute :current_py_oe_start_date, String
    attribute :current_py_oe_end_date, String
    attribute :current_py_start_date, String
    attribute :current_py_start_date_plus_one_year, String
    attribute :current_py_end_date, String
    attribute :current_py_plus_60_days, String
    attribute :py_end_on_plus_60_days, String
    attribute :current_year, String
    attribute :group_termination_plus_31_days, String

    attribute :renewal_py_oe_start_date, String
    attribute :renewal_py_oe_end_date, String
    attribute :renewal_py_start_date, String
    attribute :renewal_py_end_date, String
    attribute :renewal_year, String

    attribute :initial_py_publish_advertise_deadline, String
    attribute :initial_py_publish_due_date, String

    attribute :renewal_py_submit_soft_due_date, String
    attribute :renewal_py_submit_due_date, String
    attribute :binder_payment_due_date, String
    attribute :total_enrolled_count, String
    attribute :eligible_to_enroll_count, String
    attribute :monthly_employer_contribution_amount, Money

    # Following date fileds are defined to allow business enter tokens like <Current Plan Year END On Date, MM/DD/YYYY, + 60 Days>
    attribute :current_py_start_on, Date
    attribute :current_py_end_on, Date
    attribute :renewal_py_start_on, Date
    attribute :renewal_py_end_on, Date

    attribute :next_available_start_date, String
    attribute :next_application_deadline, String

    attribute :carrier_name, String
    attribute :renewal_carrier_name, String

    attribute :warnings, String
    attribute :enrollment_errors, Hash[Symbol => String]
    attribute :benefit_groups, Array[MergeDataModels::BenefitGroup]

    def self.stubbed_object
      reference_date = TimeKeeper.date_of_record.next_month.beginning_of_month
      current_py_start = reference_date.prev_year
      renewal_py_start = reference_date
      prev_month = current_py_start.prev_month

      plan_year =  Notifier::MergeDataModels::PlanYear.new({
        current_py_oe_start_date: (current_py_start.prev_month).strftime('%m/%d/%Y'),
        current_py_oe_end_date: (current_py_start.prev_month + 19.days).strftime('%m/%d/%Y'),
        current_py_start_date: current_py_start.strftime('%m/%d/%Y'),
        current_py_start_date_plus_one_year: current_py_start.next_year.strftime('%m/%d/%Y'),
        next_available_start_date: current_py_start.next_month.strftime('%m/%d/%Y'),
        current_py_end_date: renewal_py_start.prev_day.strftime('%m/%d/%Y'),
        next_application_deadline: current_py_start.strftime('%m/%d/%Y'),
        current_py_plus_60_days: (renewal_py_start.prev_day + 60.days).strftime('%m/%d/%Y'),
        py_end_on_plus_60_days: (renewal_py_start.prev_day + 60.days).strftime('%m/%d/%Y'),
        current_year: current_py_start.year,
        group_termination_plus_31_days: (renewal_py_start.prev_day + 31.days).strftime('%m/%d/%Y'),
        renewal_py_oe_start_date: renewal_py_start.prev_month.strftime('%m/%d/%Y'),
        renewal_py_oe_end_date: (renewal_py_start.prev_month + 19.days).strftime('%m/%d/%Y'),
        renewal_py_start_date: renewal_py_start.strftime('%m/%d/%Y'),
        renewal_py_end_date: renewal_py_start.next_year.prev_day.strftime('%m/%d/%Y'),
        renewal_year: renewal_py_start.year,
        initial_py_publish_advertise_deadline: Date.new(prev_month.year, prev_month.month, Settings.aca.shop_market.initial_application.advertised_deadline_of_month).strftime('%m/%d/%Y'),
        initial_py_publish_due_date: Date.new(prev_month.year, prev_month.month, Settings.aca.shop_market.initial_application.publish_due_day_of_month).strftime('%m/%d/%Y'),
        renewal_py_submit_soft_due_date: (renewal_py_start.prev_month + 9.days).strftime('%m/%d/%Y'),
        renewal_py_submit_due_date: (renewal_py_start.prev_month + 14.days).strftime('%m/%d/%Y'),
        binder_payment_due_date: (current_py_start.prev_month + 22.days).strftime('%m/%d/%Y'),
        current_py_start_on: current_py_start,
        current_py_end_on: renewal_py_start.prev_day,
        renewal_py_start_on: renewal_py_start,
        renewal_py_end_on: renewal_py_start.next_year.prev_day,
        carrier_name: 'Kaiser',
        renewal_carrier_name: 'Kaiser',
        binder_due_date: '09/25/2017',
        renewal_binder_due_data: '09/25/2017',
        ivl_open_enrollment_end_on: '01/31/2018',
        ivl_open_enrollment_start_on: '11/01/2017',
        warnings: "Full Time Equivalent must be 1-50",
        enrollment_errors: "One non-owner employee enrolled in health coverage",
        total_enrolled_count: '2',
        eligible_to_enroll_count: '6',
        monthly_employer_contribution_amount: "$216.34"
      })
      plan_year.benefit_groups = Notifier::MergeDataModels::BenefitGroup.stubbed_object
      plan_year
    end
  end
end
