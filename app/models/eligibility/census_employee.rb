module Eligibility
  module CensusEmployee

    def coverage_effective_on(package = nil)
      package = possible_benefit_package if (package.blank? || package.is_conversion?) # cautious
      if package.present?
        
        effective_on_date = package.effective_on_for(hired_on)
        if newly_designated_eligible? || newly_designated_linked?
          effective_on_date = [effective_on_date, newly_eligible_earlist_eligible_date].max
        end

        effective_on_date
      end
    end

    def new_hire_enrollment_period
      start_on = [hired_on, TimeKeeper.date_according_to_exchange_at(created_at)].max
      end_on = earliest_eligible_date.present? ? [start_on + 30.days, earliest_eligible_date].max : (start_on + 30.days)
      (start_on.beginning_of_day)..(end_on.end_of_day)
    end

    # TODO: eligibility rule different for active and renewal plan years
    def earliest_eligible_date
      benefit_group_assignment = renewal_benefit_group_assignment || active_benefit_group_assignment
      
      if benefit_group_assignment
        benefit_group_assignment.benefit_group.eligible_on(hired_on)
      end
    end

    def newly_eligible_earlist_eligible_date
      benefit_group_assignment = renewal_benefit_group_assignment || active_benefit_group_assignment
      benefit_group_assignment.benefit_group.start_on
    end

    def earliest_effective_date
      benefit_group_assignment = renewal_benefit_group_assignment || active_benefit_group_assignment
      
      if benefit_group_assignment
        benefit_group_assignment.benefit_group.effective_on_for(hired_on)
      end
    end

    def under_new_hire_enrollment_period?
      new_hire_enrollment_period.cover?(TimeKeeper.date_of_record)
    end
  end
end
