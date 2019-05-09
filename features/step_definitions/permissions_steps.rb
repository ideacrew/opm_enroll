When(/^Hbx Admin clicks on Employers link$/) do
  click_link 'Employers'
end

Then(/^Hbx Admin should see an Force Publish button$/) do
  expect(page).to have_content("Force Publish")
end

Then(/^Hbx Admin should not see an Force Publish button$/) do
  expect(page).not_to have_content("Force Publish")
end

And(/^system date is between submission deadline & application effective date$/) do
  allow(TimeKeeper).to receive(:date_of_record).and_return((@custom_plan_year.start_on - 3.days))
end
