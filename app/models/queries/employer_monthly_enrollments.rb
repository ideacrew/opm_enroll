module Queries
  class EmployerMonthlyEnrollments
    def initialize(employer_profile, b_date = nil)
      @employer_profile = employer_profile
      @billing_date = b_date
    end

    def decorate_enrollments_and_calculate_totals(found_enrollments, bg_cache, plan_cache)
      found_enrollments.inject({:hbx_enrollments => found_enrollments, :total_employer_contribution => 0.00, :total_employee_cost => 0.00, :total_premium => 0.00}) do |acc, fe|
        benefit_group = bg_cache[fe.benefit_group_id]
        plan = plan_cache[fe.plan_id]
        decorator = nil
        if benefit_group.is_congress?
          decorator = PlanCostDecoratorCongress.new(plan, fe, benefit_group)
        else
          if benefit_group.sole_source? && (!plan.dental?)
            decorator = CompositeRatedPlanCostDecorator.new(plan, benefit_group, fe.composite_rating_tier, fe.is_cobra_status?)
          else
            reference_plan = (fe.coverage_kind == 'dental' ?  benefit_group.dental_reference_plan : benefit_group.reference_plan)
            decorator = PlanCostDecorator.new(plan_cache[fe.plan_id], fe, benefit_group, reference_plan)
          end
        end
        acc[:total_employer_contribution] = acc[:total_employer_contribution] + decorator.total_employer_contribution
        acc[:total_employee_cost] = acc[:total_employee_cost] + decorator.total_employee_cost
        acc[:total_premium] = acc[:total_premium] + decorator.total_premium
        fe.assign_cost_decorator(decorator)
        acc
      end
    end

    def get_decorators_for_enrollments
      benefit_groups = @employer_profile.plan_years.flat_map(&:benefit_groups)
      plan_year, billing_report_date = @employer_profile.billing_plan_year(@billing_date)
      return nil if plan_year.nil?
      enrollment_calculations = plan_year.filter_active_enrollments_by_date(billing_report_date)
      plan_ids =  enrollment_calculations.map(&:plan_id)
      enrollment_ids = enrollment_calculations.map(&:hbx_enrollment_id)
      people_ids = enrollment_calculations.flat_map(&:family_members).map do |fm|
        fm["person_id"]
      end
      people_used  = Person.where(:id => {"$in" => people_ids})
      plans_used = Plan.where(:id => {"$in" => plan_ids})
      people_cache = people_used.inject({}) do |acc, person|
        acc[person.id] = person
        acc
      end
      plan_cache = plans_used.inject({}) do |acc, plan|
        acc[plan.id] = plan
        acc
      end
      bg_cache = benefit_groups.inject({}) do |acc, bg|
        acc[bg.id] = bg
        acc
      end
      found_enrollments = find_enrollments(enrollment_ids, people_cache)
      decorate_enrollments_and_calculate_totals(found_enrollments, bg_cache, plan_cache)
    end

    def find_enrollments(enrollment_ids, people_cache)
      families = Family.where("households.hbx_enrollments._id" => {"$in" => enrollment_ids})
      families.flat_map(&:households).flat_map(&:hbx_enrollments).select do |hen|
        enrollment_ids.include?(hen.id).tap do |val|
          if val
            hen.family.family_members.each do |fm|
              fm.person = people_cache[fm.person_id]
            end
          end
        end
      end
    end
  end
end
