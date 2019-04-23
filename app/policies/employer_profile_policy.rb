class EmployerProfilePolicy < ApplicationPolicy

  def list_enrollments?
    return false unless person=user.person
    return true unless hbx_staff = person.hbx_staff_role
    hbx_staff.permission.list_enrollments
  end

  def updateable?
    return true unless role = user.person && user.person.hbx_staff_role
    role.permission.modify_employer
  end

  def revert_application?
    return true unless role = user.person.hbx_staff_role
    role.permission.revert_application
  end

  def fire_general_agency?
    return false unless user.person
    return true if user.person.hbx_staff_role
    broker_role = user.person.broker_role
    return false unless broker_role
    assigned_broker = record.broker_agency_accounts.any? { |account| account.writing_agent_id == broker_role.id }
    return true if assigned_broker
    record.general_agency_accounts.any? { |account| account.broker_role_id == broker_role.id }
  end
end
