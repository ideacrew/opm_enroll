FactoryGirl.define do
  factory :permission do
    modify_family true
    modify_employer true
    revert_application true
    list_enrollments true
    send_broker_agency_message true
    approve_broker true
    approve_ga true
    modify_admin_tabs true
    view_admin_tabs  true
    can_transition_family_members true

    trait :hbx_staff do
      can_complete_resident_application true
      can_add_sep true
      can_access_new_consumer_application_sub_tab true
      can_access_identity_verification_sub_tab true
      can_access_outstanding_verification_sub_tab true
      name 'hbx_staff'
    end

    trait :hbx_update_ssn do
      can_update_ssn true
    end

    trait :hbx_read_only do
      modify_family true
      modify_employer false
      revert_application false
      list_enrollments true
      send_broker_agency_message false
      approve_broker false
      approve_ga false
      modify_admin_tabs false
      view_admin_tabs  true
      can_access_outstanding_verification_sub_tab true
      name 'hbx_read_only'
    end

    trait :hbx_csr_supervisor do
      modify_family true
      modify_employer true
      revert_application true
      list_enrollments true
      send_broker_agency_message false
      approve_broker false
      approve_ga false
      modify_admin_tabs false
      view_admin_tabs  false
      can_access_new_consumer_application_sub_tab true
      name 'hbx_csr_supervisor'
    end
    
    trait :hbx_tier3 do
      can_view_username_and_email true
      can_lock_unlock true
      can_reset_password true
      can_force_publish true
    end

    trait :hbx_csr_tier2 do
      modify_family true
      modify_employer true
      revert_application false
      list_enrollments false
      send_broker_agency_message false
      approve_broker false
      approve_ga false
      modify_admin_tabs false
      view_admin_tabs false
      can_access_new_consumer_application_sub_tab true
      name 'hbx_csr_tier2'
    end

    trait :hbx_csr_tier1 do
      modify_family true
      modify_employer false
      revert_application false
      list_enrollments false
      send_broker_agency_message false
      approve_broker false
      approve_ga false
      modify_admin_tabs false
      view_admin_tabs  false
      can_access_new_consumer_application_sub_tab true
      name 'hbx_csr_tier1'
    end


    trait :developer do
      modify_family false
      modify_employer false
      revert_application false
      list_enrollments false
      send_broker_agency_message false
      approve_broker false
      approve_ga false
      modify_admin_tabs false
      view_admin_tabs  false
      name 'developer'
    end

    trait :super_admin do
      can_complete_resident_application true
      can_add_sep true
      can_access_new_consumer_application_sub_tab true
      can_access_identity_verification_sub_tab true
      can_access_outstanding_verification_sub_tab true
      can_view_username_and_email true
      can_force_publish true
      name 'super_admin'
    end
  end
end