module UserWorld

  def employee(employer=nil)
    if @employee
      @employee
    else
      employer_staff_role = FactoryGirl.build(:benefit_sponsor_employer_staff_role, aasm_state:'is_active', benefit_sponsor_employer_profile_id: employer.profiles.first.id)
      person = FactoryGirl.create(:person, employer_staff_roles:[employer_staff_role])
      @employee = FactoryGirl.create(:user, :person => person)
    end
  end

  def broker(broker_agency=nil)
    if @broker
      @broker
    else
      person = FactoryGirl.create(:person)
      broker_role = FactoryGirl.build(:broker_role, aasm_state: 'active', benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id, person: person)
      @broker = FactoryGirl.create(:user, :person => person)
    end
  end

  def admin(subrole)
    if @admin
      @admin
    else
      subrole = subrole.parameterize.underscore
      hbx_profile_id = FactoryGirl.create(:hbx_profile).id
      person = FactoryGirl.create(:person)
      if subrole.blank?
        raise "No subrole was provided"
      end
      if Permission.where(name:subrole).present?
        permission_id = Permission.where(name:subrole).first.id
      else
        raise "No permission was found for subrole #{subrole}"
      end
      hbx_staff_role = HbxStaffRole.create!( person: person, permission_id: permission_id, subrole: subrole, hbx_profile_id: hbx_profile_id)
      @admin = FactoryGirl.create(:user, :person => person)
    end
  end

end

World(UserWorld)

Given(/^that a user with a (.*?) role(?: with (.*?) subrole)? exists and is logged in$/) do |type, subrole|
  case type
    when "Employer"
      user = employee(employer)
    when "Broker"
      user = broker(broker_agency_profile)
    when "HBX staff"
      user = admin(subrole)
  end
  login_as(user, :scope => :user)
end

And(/^the user is on the Employer Index of the Admin Dashboard$/) do
  visit exchanges_hbx_profiles_path
  find('.interaction-click-control-employers').click
end

When(/^the user clicks Action for that Employer$/) do
  find('.dropdown.pull-right', text: 'Actions').click
end

Then(/^the user will see the Extend Open Enrollment button$/) do
  expect(page).to have_css('.btn.btn-xs', text: 'Extend Open Enrollment')
end

Then(/^the user will not see the Extend Open Enrollment button$/) do
  expect(page).to_not have_css('.btn.btn-xs', text: 'Extend Open Enrollment')
end

When(/^the user clicks Extend Open Enrollment$/) do
  find('.btn.btn-xs', text: 'Extend Open Enrollment').click
end

When(/^the user clicks Edit Open Enrollment$/) do
  find('a.btn.btn-primary.btn-sm', text: 'Edit Open Enrollment').trigger('click')
end

Then(/^the user clicks Extend Open Enrollment button$/) do
  find('input[value="Extend Open Enrollment"]').trigger('click')
end

Then(/^the user enters a new open enrollment end date$/) do
  input = find('input.hasDatepicker')
  input.set(Date.today+1.week)
end

Then(/^the user will see the Create Plan Year button$/) do
  expect(page).to have_css('.btn.btn-xs', text: 'Create Plan Year')
end

Then(/^the user will not see the Create Plan Year button$/) do
  expect(page).to_not have_css('.btn.btn-xs', text: 'Create Plan Year')
end

When(/^the user clicks the Create Plan Year button for this Employer$/) do
  find('.btn.btn-xs', text: 'Create Plan Year').click
end

Then(/^the user will see the Create Plan Year option row$/) do
  expect(page).to have_css('label', text: 'Effective Start Date')
  expect(page).to have_css('label', text: 'Effective End Date')
  expect(page).to have_css('label', text: 'Full Time Employees')
  expect(page).to have_css('label', text: 'Open Enrollment Start Date')
  expect(page).to have_css('label', text: 'Open Enrollment End Date')
end

Then(/^the user selects an Effective Start Date from the Create Plan Year form$/) do
  first_element = find("#baStartDate > option:nth-child(2)").text
  select(first_element, :from => "baStartDate")
end

When(/^the user selects an input in the Effective Start date drop down$/) do
  find('a', text: 'Effective Start Date')
end

When(/^the user completely fills out the Create Plan Year Form$/) do
  fill_in_admin_create_plan_year_form
end

When(/^the user partially fills out the Create Plan Year Form$/)  do
  fill_in_partial_create_plan_year_form
end

When(/^the user clicks the X icon on the Create Plan Year form$/) do
  find('#closeBAForm').trigger('click')
end

Then(/^the Effective End Date will populate with a date equal to one year minus (\d+) day from the Effective Start Date$/) do |arg1|
  pending # Write code here that turns the phrase above into concrete actions
end

Then(/^the Effective End Date will not be editable\.$/) do
  pending # Write code here that turns the phrase above into concrete actions
end

Then(/^the user will( not)? see the Change FEIN button$/) do |visible|
  if visible.blank?
     expect(page).to have_css('.btn.btn-xs', text: 'Change FEIN')
  else
     expect(page).to_not have_css('.btn.btn-xs', text: 'Change FEIN')
   end
end

Then(/^the user will( not)? see the Force Publish button$/) do |visible|
  if visible.blank?
    expect(page).to have_css('.btn.btn-xs', text: 'Force Publish')
  else
    expect(page).to_not have_css('.btn.btn-xs', text: 'Force Publish')
  end
end

And(/^system date is between submission deadline & OE End date$/) do
  allow(TimeKeeper).to receive(:date_of_record).and_return((initial_application.open_enrollment_period.max - 1.day))
end

And(/^system date is between submission deadline & application effective date$/) do
  allow(TimeKeeper).to receive(:date_of_record).and_return((initial_application.start_on - 3.days))
end
