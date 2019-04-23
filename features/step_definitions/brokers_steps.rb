When(/^.+ visits the HBX Broker Registration form$/) do
  visit '/'
  find(".interaction-click-control-broker-registration", wait: 10).click
end

When(/^Primary Broker should see the New Broker Agency form$/) do
  wait_for_ajax
  expect(page).to have_css("#broker_agency_form")
end

When(/^.+ enters personal information$/) do
  visit "/broker_registration"

  fill_in 'organization[first_name]', with: 'Ricky'
  fill_in 'organization[last_name]', with: 'Martin'
  fill_in 'jq_datepicker_ignore_organization[dob]', with: '10/10/1984'
  find('.interaction-field-control-person-email').click
  fill_in 'organization[email]', with: 'ricky.martin@example.com'
  fill_in 'organization[npn]', with: '109109109'
end

And(/^.+ enters broker agency information for individual markets$/) do
  fill_in 'organization[legal_name]', with: "Logistics Inc"
  fill_in 'organization[dba]', with: "Logistics Inc"
  # Auto-Generates FEIN
  # fill_in 'organization[fein]', with: "890890891"

  # this field was hidden 4/13/2016
  # find(:xpath, "//p[@class='label'][contains(., 'Select Entity Kind')]").click
  # find(:xpath, "//li[contains(., 'C Corporation')]").click

  find(:xpath, "//p[@class='label'][contains(., 'Select Practice Area')]").click
  find(:xpath, "//li[contains(., 'Both - Individual & Family AND Small Business Marketplaces')]").click

  find('button.multiselect').click
  find(:xpath, '//label[input[@value="bn"]]').click
  find(:xpath, '//label[input[@value="fr"]]').click

  find(:xpath, "//label[input[@name='organization[accept_new_clients]']]").trigger('click')
  find(:xpath, "//label[input[@name='organization[working_hours]']]").trigger('click')
end

And(/^.+ enters broker agency information for SHOP markets$/) do
  fill_in 'organization[legal_name]', with: "Logistics Inc"
  fill_in 'organization[dba]', with: "Logistics Inc"
  # Auto-Generates FEIN
  # fill_in 'organization[fein]', with: "890890891"

  # this field was hidden 4/13/2016
  # find(:xpath, "//p[@class='label'][contains(., 'Select Entity Kind')]").click
  # find(:xpath, "//li[contains(., 'C Corporation')]").click

  # find(:xpath, "//p[@class='label'][contains(., 'Select Practice Area')]").click
  # find(:xpath, "//li[contains(., 'Small Business Marketplace ONLY')]").click

  find('button.multiselect').click
  find(:xpath, '//label[input[@value="bn"]]').click
  find(:xpath, '//label[input[@value="fr"]]').click

  find(:xpath, "//label[input[@name='organization[accept_new_clients]']]").trigger('click')
  find(:xpath, "//label[input[@name='organization[working_hours]']]").trigger('click')

  fill_in 'organization[ach_record][routing_number]', with: '123456789'
  fill_in 'organization[ach_record][routing_number_confirmation]', with: '123456789'
  fill_in 'organization[ach_record][account_number]', with: '9999999999999999'
  find("#organization_ach_record_routing_number_confirmation").send_keys([:control, "a"])
end

And(/^.+ clicks? on Create Broker Agency$/) do
  wait_for_ajax
  page.find('h1', text: 'Broker Registration').click
  wait_for_ajax
  click_button "Create Broker Agency", wait: 6
end

Then(/^.+ should see broker registration successful message$/) do
  wait_for_ajax
  expect(page).to have_content('Your registration has been submitted. A response will be sent to the email address you provided once your application is reviewed.')
end

And(/^.+ should see the list of broker applicants$/) do
end

Then(/^.+ clicks? on the current broker applicant show button$/) do
  find('.interaction-click-control-broker-show').trigger('click')
end

And(/^.+ should see the broker application with carrier appointments$/) do
  if (Settings.aca.broker_carrier_appointments_enabled)
    find_all("[id^=person_broker_role_attributes_carrier_appointments_]").each do |checkbox| 
      checkbox.should be_checked 
    end
    expect(page).to have_content("Carrier appointments for broker are not necessary for participation in #{Settings.site.long_name}")
  end
end

And(/^.+ clicks? on approve broker button$/) do
  find('.interaction-click-control-broker-approve').trigger('click')
end

Then(/^.+ should see the broker successfully approved message$/) do
  expect(page).to have_content('Broker applicant approved successfully.')
end

And(/^.+ should receive an invitation email$/) do
  open_email("ricky.martin@example.com", :with_subject => "Congratulations! Your Broker Application for the #{Settings.site.short_name} for Business has been Approved!")
  expect(current_email.to).to eq(["ricky.martin@example.com"])
  #current_email.should have_subject("Invitation from your Employer to Sign up for Health Insurance at #{Settings.site.short_name} ")
end

When(/^.+ visits? invitation url in email$/) do
  invitation_link = links_in_email(current_email).first
  invitation_link.sub!(/http\:\/\/127\.0\.0\.1\:3000/, '')
  visit(invitation_link)
end

Then(/^.+ should see the login page$/) do
  find('.interaction-click-control-sign-in')
end

Then(/^.+ should see the create account page$/) do
  find('.interaction-click-control-create-account')
end

When(/^.+ clicks? on Create Account$/) do
  click_link 'Create account'
end

When(/^.+ registers? with valid information$/) do
  fill_in "user[oim_id]", with: "ricky.martin@example.com"
  fill_in "user[password]", with: "aA1!aA1!aA1!"
  fill_in "user[password_confirmation]", with: "aA1!aA1!aA1!"
  click_button 'Create account'
end

Then(/^.+ should see bank information$/) do
  expect(page).to have_content('Big Bank')
end

Then(/^.+ should see successful message with broker agency home page$/) do
  expect(page).to have_content("Welcome to #{Settings.site.short_name}. Your account has been created.")

  expect(page).to have_content('Broker Agency : Logistics Inc')
end

Then(/^.+ should see no active broker$/) do
  expect(page).to have_content('You have no active Broker')
end

When(/^.+ clicks? on Browse Brokers button$/) do
  find('.interaction-click-control-browse-brokers').click
end

Then(/^.+ should see broker agencies index view$/) do
  #TODO add AJAX handling
  wait_for_ajax(3)
  expect(page).to have_content('Broker Agencies', :wait => 5)
end

When(/^.+ searches broker agency by name$/) do
  find('.broker_agencies_search')

  fill_in 'q', with: 'Logistics'

  find('.search-wp .btn').click
end

Then(/^.+ should see broker agency$/) do
  expect(page).to have_content('Logistics Inc')
end

Then(/^.+ clicks? select broker button$/) do
  click_link 'Select Broker'
end

Then(/^.+ should see confirm modal dialog box$/) do
  expect(page).to have_content('Broker Selection Confirmation')
end

Then(/^.+ confirms? broker selection$/) do
  within '.modal-dialog' do
    find('input.btn-primary').click
  end
end

Then(/^.+ should see broker selected successful message$/) do
  wait_for_ajax(1,0.5)
  expect(page).to have_content("Your broker has been notified of your selection and should contact you shortly. You can always call or email them directly. If this is not the broker you want to use, select 'Change Broker'.")
end

And (/^.+ should see broker active for the employer$/) do
  expect(page).to have_content('Logistics Inc')
  expect(page).to have_content(/RICKY MARTIN/i)
end

When(/^.+ terminates broker$/) do
  find('.interaction-click-control-change-broker').click
  wait_for_ajax(2,2)
  within '.modal-dialog' do
    click_link 'Terminate Broker'
  end
end

Then(/^.+ should see broker terminated message$/) do
  expect(page).to have_content('Broker terminated successfully.')
end

Then(/^.+ should see Employer and click on legal name$/) do
  click_link 'Legal LLC'
end

Then(/^.+ should see the Employer Profile page as Broker$/) do
  expect(page).to have_content("I'm a Broker")
end

Then(/^.* creates and publishes a plan year$/) do
  find('.interaction-click-control-benefits').click
  find('.interaction-click-control-add-plan-year').click

  find(:xpath, '//p[@class="label"][contains(., "SELECT START ON")]').click
  find(:xpath, '//div[div/p[contains(., "SELECT START ON")]]//li[@data-index="1"]').click

  fill_in 'plan_year[fte_count]', with: '3'
  find('.interaction-click-control-continue').click

  fill_in "plan_year[benefit_groups_attributes][0][title]", with: "Silver PPO Group"

  find(:xpath, '//li/label[@for="plan_year_benefit_groups_attributes_0_plan_option_kind_single_carrier"]').click
  wait_for_ajax(10)
  find('.carriers-tab a').click
  wait_for_ajax(10,2)
  find('.reference-plan label').click
  wait_for_ajax(10)
  fill_in "plan_year[benefit_groups_attributes][0][relationship_benefits_attributes][0][premium_pct]", with: 50
  fill_in "plan_year[benefit_groups_attributes][0][relationship_benefits_attributes][1][premium_pct]", with: 50
  fill_in "plan_year[benefit_groups_attributes][0][relationship_benefits_attributes][2][premium_pct]", with: 50
  fill_in "plan_year[benefit_groups_attributes][0][relationship_benefits_attributes][3][premium_pct]", with: 50

  find('.interaction-click-control-create-plan-year').trigger('click')
  find('.alert-notice')

  if (Settings.aca.enforce_employer_attestation.to_s == "true")
    find('.interaction-click-control-documents').click
    wait_for_ajax
    find('.interaction-click-control-upload').click
    wait_for_ajax
    find('#subject_Employee_Attestation').click
    # There is no way to actually trigger the click and upload functionality
    # with a JS driver.
    # So we commit 2 sins:
    #   1) We make the file input visible so we can set it.
    #   2) We make the submit button visible so we can click it.
    execute_script(<<-JSCODE)
     $('#modal-wrapper div.employee-upload input[type=file]').attr("style", "display: block;");
    JSCODE
    wait_for_ajax
    attach_file("file", "#{Rails.root}/test/JavaScript.pdf")
    execute_script(<<-JSCODE)
     $('#modal-wrapper div.employee-upload input[type=submit]').css({"visibility": "visible", "display": "inline-block"});
    JSCODE
    find("input[type=submit][value=Upload]").click
    wait_for_ajax
  end

  find('.interaction-click-control-benefits').click
  find('.interaction-click-control-publish-plan-year').click
  wait_for_ajax
end

Then(/^.+ sees employer census family created$/) do
  expect(page).to have_content('successfully created')
end

Then(/^(?:(?!Employee).)+ should see the matched employee record form$/) do
  screenshot("broker_employer_search_results")
  expect(page).to have_content('Legal LLC')
end

Then(/^Broker Assisted is a family$/) do
  find(:xpath, "//li[contains(., 'Families')]/a").click
  expect(page).to have_content('Broker Assisted')
end

Then(/^.+ goes to the Consumer page$/) do
  click_link 'Broker Assisted'
  expect(page).to have_content("My #{Settings.site.short_name}")
end

# Then(/^.+ is on the consumer home page$/) do
#   @browser.a(class: 'interaction-click-control-shop-for-plans').wait_until_present
# end

Then(/^.+ shops for plans$/) do
  @browser.a(class: 'interaction-click-control-shop-for-plans').click
end

Then(/^.+ sees covered family members$/) do
  wait_and_confirm_text(/Choose Benefits: Covered Family Members/)
  @browser.element(id: 'btn-continue').click
end

Then(/^.+ choses a healthcare plan$/) do
  wait_and_confirm_text(/Choose Plan/i)
  wait_and_confirm_text(/Apply/)
  plan = @browser.a(class: 'interaction-click-control-select-plan')
  plan.click
end

Then(/^.+ continues to the consumer home page$/) do
  wait_and_confirm_text(/Continue/)
  @browser.a(text: /Continue/).click
end

Given(/^zip code for county exists as rate reference$/) do
  FactoryGirl.create(:rating_area, zip_code: '01010', county_name: 'Worcester', rating_area: Settings.aca.rating_areas.first,
    zip_code_in_multiple_counties: true)
end

Given(/^a valid ach record exists$/) do
  FactoryGirl.create(:ach_record, routing_number: '123456789', bank_name: 'Big Bank')
end

#
Given(/^enters the existing zip code$/) do
  fill_in 'organization[office_locations_attributes][0][address_attributes][zip]', with: '01010'
end

Then(/^the county should be autopopulated appropriately$/) do
  wait_for_ajax
  select 'Test County', :from => "organization[office_locations_attributes][0][address_attributes][county]"
  expect(page).to have_select("organization[office_locations_attributes][0][address_attributes][county]", :selected => 'Test County')
end

Given(/^enters a non existing zip code$/) do
  fill_in 'organization[office_locations_attributes][0][address_attributes][zip]', with: '11011'
end

Then(/^the county should not be autopopulated appropriately$/) do
  wait_for_ajax
  expect(page).not_to have_select("organization[office_locations_attributes][0][address_attributes][county]", :options => ['Test County'])
end
