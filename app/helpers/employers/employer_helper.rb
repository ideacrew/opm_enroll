module Employers::EmployerHelper
  def address_kind
    @family.try(:census_employee).try(:address).try(:kind) || 'home'
  end

  def employee_state_format(employee_state=nil, termination_date=nil)
    if employee_state == "employee_termination_pending" && termination_date.present?
      return "Termination Pending " + termination_date.to_s
    elsif employee_state == 'employee_role_linked'
      return 'Account Linked'
    elsif employee_state == 'eligible'
      return 'Account Linked'
    else
      return employee_state.humanize
    end
  end
  
  def enrollment_state(census_employee=nil)
    humanize_enrollment_states(census_employee.active_benefit_group_assignment).gsub("Coverage Selected", "Enrolled").gsub("Coverage Waived", "Waived").gsub("Coverage Terminated", "Terminated").gsub("Coverage Termination Pending", "Coverage Termination Pending").html_safe
  end

  def renewal_enrollment_state(census_employee=nil)
    humanize_enrollment_states(census_employee.renewal_benefit_group_assignment).gsub("Coverage Renewing", "Auto-Renewing").gsub("Coverage Selected", "Enrolling").gsub("Coverage Waived", "Waiving").gsub("Coverage Terminated", "Terminating").html_safe
  end

  def humanize_enrollment_states(benefit_group_assignment)
    enrollment_states = []

    if benefit_group_assignment
      enrollments = benefit_group_assignment.hbx_enrollments

      %W(health dental).each do |coverage_kind|
        if coverage = enrollments.detect{|enrollment| enrollment.coverage_kind == coverage_kind}
          enrollment_states << "#{employee_benefit_group_assignment_status(benefit_group_assignment.census_employee, coverage.aasm_state)} (#{coverage_kind})"
        end
      end
      enrollment_states << '' if enrollment_states.compact.empty?
    end

    "#{enrollment_states.compact.join('<br/> ').titleize.to_s}".html_safe

  end

  def benefit_group_assignment_status(enrollment_status)
    assignment_mapping = {
      'coverage_renewing' => HbxEnrollment::RENEWAL_STATUSES,
      'coverage_terminated' => HbxEnrollment::TERMINATED_STATUSES,
      'coverage_termination_pending' => ["coverage_termination_pending"],
      'coverage_selected' => HbxEnrollment::ENROLLED_STATUSES - ["coverage_termination_pending"],
      'coverage_waived' => HbxEnrollment::WAIVED_STATUSES
    }

    assignment_mapping.each do |bgsm_state, enrollment_statuses|
      if enrollment_statuses.include?(enrollment_status.to_s)
        return bgsm_state
      end
    end
  end

  def employee_benefit_group_assignment_status(census_employee, enrollment_status)
    state = benefit_group_assignment_status(enrollment_status)
    if census_employee.is_cobra_status?
      case state
      when 'coverage_waived'
        'cobra_waived'
      when 'coverage_renewing'
        'cobra_renewed'
      else
        state
      end
    else
      state
    end
  end

  def render_plan_offerings(benefit_group)

    assignment_mapping.each do |bgsm_state, enrollment_statuses|
      if enrollment_statuses.include?(enrollment_status.to_s)
        return bgsm_state
      end
    end
  end


  def invoice_formated_date(date)
    date.strftime("%m/%d/%Y")
  end

  def invoice_coverage_date(date)
    "#{date.next_month.beginning_of_month.strftime('%b %Y')}" rescue nil
  end

  def coverage_kind(census_employee=nil)
    return "" if census_employee.blank? || census_employee.employee_role.blank?
    enrolled = census_employee.active_benefit_group_assignment.try(:aasm_state)
    if enrolled.present? && enrolled != "initialized"
      begin
        #kind = census_employee.employee_role.person.primary_family.enrolled_including_waived_hbx_enrollments.map(&:plan).map(&:coverage_kind).sort.reverse.uniq.join(", ")
        kind = census_employee.employee_role.person.primary_family.enrolled_including_waived_hbx_enrollments.map(&:plan).map(&:coverage_kind).sort.reverse.join(", ")
      rescue
        kind = ""
      end
    else
      kind = ""
    end
    return kind.titleize
  end

  def render_plan_offerings(benefit_group, coverage_type)
    reference_plan = benefit_group.reference_plan
    if coverage_type == ".dental" && benefit_group.dental_plan_option_kind == "single_plan"
      plan_count = benefit_group.elected_dental_plan_ids.count
      "#{plan_count} Plans"
    elsif coverage_type == ".dental" && benefit_group.dental_plan_option_kind == "single_carrier"
      plan_count = Plan.shop_dental_by_active_year(reference_plan.active_year).by_carrier_profile(reference_plan.carrier_profile).count
      "All #{reference_plan.carrier_profile.legal_name} Plans (#{plan_count})"
    else
      return "1 Plan Only" if benefit_group.single_plan_type?
      if benefit_group.plan_option_kind == "single_carrier"
        plan_count = Plan.shop_health_by_active_year(reference_plan.active_year).by_carrier_profile(reference_plan.carrier_profile).count
        "All #{reference_plan.carrier_profile.legal_name} Plans (#{plan_count})"
      else
        plan_count = Plan.shop_health_by_active_year(reference_plan.active_year).by_health_metal_levels([reference_plan.metal_level]).count
        "#{reference_plan.metal_level.titleize} Plans (#{plan_count})"
      end
    end
  end

  def get_benefit_groups_for_census_employee
    plan_years = @employer_profile.plan_years.select{|py| (PlanYear::PUBLISHED + ['draft']).include?(py.aasm_state) && py.end_on > TimeKeeper.date_of_record}
    benefit_groups = plan_years.flat_map(&:benefit_groups)
    renewing_benefit_groups = @employer_profile.renewing_plan_year.benefit_groups if @employer_profile.renewing_plan_year
    return benefit_groups, (renewing_benefit_groups || [])
  end

  def cobra_effective_date(census_employee)
    disabled = current_user.has_hbx_staff_role? ? false : true
    content_tag(:div) do
     content_tag(:span,"COBRA/Continuation Effective Date:  ") +
      content_tag(:span, :class=>"confirm-cobra" ,:style=>"display:inline;") do
        content_tag(:input, nil, :type => "text" ,:class => "text-center date-picker", :value => census_employee.suggested_cobra_effective_date , :disabled => disabled )
      end
    end.html_safe
  end

  def cobra_button(census_employee)    
    disabled = true
    if census_employee.is_cobra_coverage_eligible?
      if current_user.has_hbx_staff_role? || !census_employee.cobra_eligibility_expired?
        disabled = false
      end
    end

    button_text = 'COBRA'
    toggle_class = ".cobra_confirm_"
    if census_employee.cobra_terminated?
      button_text = 'COBRA REINSTATE'
      toggle_class = ".cobra_reinstate_"
      disabled = !current_user.has_hbx_staff_role?
    end
    content_tag(:a, :class => "show_confirm show_cobra_confirm btn btn-primary" , :id => "show_cobra_confirm_#{census_employee.id}" ,:disabled => disabled) do
      content_tag(:span, button_text, :class => "hidden-xs hidden-sm visible-md visible-lg",
        :onclick => "$(this).closest('tr').nextAll('#{toggle_class}#{census_employee.id}').toggle()")
    end
  end

  def show_cobra_fields?(employer_profile, user)
    return true if user && user.has_hbx_staff_role?
    return false if employer_profile.blank?

    plan_year = employer_profile.renewing_plan_year || employer_profile.active_plan_year || employer_profile.published_plan_year
    
    return false if plan_year.blank?
    return false if plan_year.is_renewing? && !employer_profile.is_converting?

    plan_year.open_enrollment_contains?(TimeKeeper.date_of_record)
  end

  def rehire_date_min(census_employee)
    return 0 if census_employee.blank?

    if census_employee.employment_terminated?
      (census_employee.employment_terminated_on - TimeKeeper.date_of_record).to_i + 1
    elsif census_employee.cobra_eligible? || census_employee.cobra_linked? || census_employee.cobra_terminated?
      (census_employee.cobra_begin_date - TimeKeeper.date_of_record).to_i + 1
    else
      0
    end
  end

  def display_families_tab(user)
    if user.present?
      user.has_broker_agency_staff_role? || user.has_general_agency_staff_role? || user.is_active_broker?(@employer_profile)
    end
  end

  def display_employee_status_transitions(census_employee)
    content = "<input type='text' class='form-control date-picker date-field'/>" || nil if CensusEmployee::EMPLOYMENT_ACTIVE_STATES.include? census_employee.aasm_state
    content = "<input type='text' class='form-control date-picker date-field'/>" || nil if CensusEmployee::EMPLOYMENT_TERMINATED_STATES.include? census_employee.aasm_state
    links = link_to "Terminate", "javascript:;", data: { "content": "#{content}" }, onclick: "EmployerProfile.changeCensusEmployeeStatus($(this))", class: "manual" if CensusEmployee::EMPLOYMENT_ACTIVE_STATES.include? census_employee.aasm_state
    links = "#{link_to("Rehire", "javascript:;", data: { "content": "#{content}" }, onclick: "EmployerProfile.changeCensusEmployeeStatus($(this))", class: "manual")} #{link_to("COBRA", "javascript:;", onclick: "EmployerProfile.changeCensusEmployeeStatus($(this))")}" if CensusEmployee::EMPLOYMENT_TERMINATED_STATES.include? census_employee.aasm_state
    return [links, content]
  end

  def is_rehired(ce)
    (ce.coverage_terminated_on.present?  && (ce.is_eligible? || ce.employee_role_linked?))
  end

  def is_terminated(ce)
    (ce.coverage_terminated_on.present? && !(ce.is_eligible? || ce.employee_role_linked?))
  end

end
