FactoryGirl.define do
  factory :scheduled_event do
  	type 'holiday'
  	event_name 'Christmas'
  	start_time {Date.today}
  	one_time true
  	recurring_rules nil
  	offset_rule '3'
  	trait :recurring_rule do
      recurring_rules {"validations"=>{"day_of_month"=>[27]}, "rule_type"=>"IceCube::MonthlyRule", "interval"=>1}
    end
  end
end