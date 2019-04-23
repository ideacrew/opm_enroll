require File.join(Rails.root, "app", "data_migrations", "components", "fix_organization")

# This rake task used to update the required actions for an Organization.
#To Update the Fein
# RAILS_ENV=production bundle exec rake migrations:fix_organization organization_fein="011110001" action="update_fein" correct_fein="653256233"
#To Swap the Fein
# RAILS_ENV=production bundle exec rake migrations:fix_organization organization_fein="011110001" action="swap_fein" correct_fein="653256233"
#To Approve Attestation
# RAILS_ENV=production bundle exec rake migrations:fix_organization organization_fein="011110001" action="approve_attestation"
#RAILS_ENV=production bundle exec rake migrations:fix_organization organization_fein="011110001" action="update_employer_broker_agency_account" npn="74920928"
namespace :migrations do
  desc "change fein of an organization"
  FixOrganization.define_task :fix_organization => :environment
end

