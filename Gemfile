source 'https://rubygems.org'

gem 'aasm', '~> 4.8.0'
gem 'acapi', git: 'https://github.com/dchbx/acapi.git', branch: '1.3.2'
gem 'addressable', '2.3.8'
gem 'animate-rails', '~> 1.0.7'
gem 'aws-sdk', '2.2.4'
gem 'bootstrap-multiselect-rails', '~> 0.9.9'
gem 'bootstrap-slider-rails', '6.0.17'
gem 'bson', '3.2.6'
gem 'carrierwave-mongoid', :require => 'carrierwave/mongoid'
gem 'coffee-rails', '~> 4.1.0'
gem 'combine_pdf'
gem 'config', '~> 1.0.0'
gem 'devise', '~> 3.4.1'
gem 'effective_datatables', path: './project_gems/effective_datatables-2.6.14'
gem 'font-awesome-rails', '4.5.0.1'
gem 'haml'
gem 'httparty'
gem 'interactor', '3.1.0'
gem 'interactor-rails', '2.0.2'
gem 'jbuilder', '~> 2.0'
gem 'jquery-datatables-rails', '3.4.0'
gem 'jquery-rails', '4.0.5'
gem 'jquery-turbolinks'
gem 'jquery-ui-rails'
gem 'kaminari', '0.17.0'
gem 'language_list', '~> 1.1.0'
gem 'less-rails-bootstrap', '~> 3.3.1.0'
gem 'mail', '2.6.3'
gem 'maskedinput-rails'
gem 'money-rails', '~> 1.3.0'
gem 'mongo', '2.1.2'
gem 'mongo_session_store-rails4', '~> 6.0.0'
gem 'mongoid', '5.0.1'
gem 'mongoid-autoinc'
gem 'mongoid-enum'
gem 'mongoid-history'
gem 'mongoid-versioning'
gem 'mongoid_userstamp'
gem 'nokogiri', '1.6.7.2'
gem 'nokogiri-happymapper', :require => 'happymapper'
gem 'openhbx_cv2', git: 'https://github.com/dchbx/openhbx_cv2.git', branch: 'master'
gem 'prawn', :git => 'https://github.com/prawnpdf/prawn.git', :ref => '8028ca0cd2'
gem 'pundit', '~> 1.0.1'
gem 'rails', '4.2.7.1'
gem 'rails-i18n', '4.0.8'
gem 'recaptcha', '1.1.0'
gem 'redis-rails'
gem 'resque'
gem 'roo', '~> 2.1.0'
gem 'ruby-saml', '~> 1.3.0'
gem 'sass-rails', '~> 5.0'
gem 'slim-rails'
gem 'sprockets', '~> 2.12.3'
gem 'symmetric-encryption', '~> 3.6.0'
gem 'therubyracer', platforms: :ruby
gem 'turbolinks','2.5.3'
gem 'uglifier', '>= 1.3.0'
gem 'faker', '~> 1.8', '>= 1.8.7'
gem 'virtus'
gem 'wicked_pdf', '1.0.6'
gem 'wkhtmltopdf-binary-edge', '~> 0.12.3.0'

#######################################################
# Removed gems
#######################################################
#
# gem 'acapi', path: '../acapi'
# gem 'bcrypt', '~> 3.1.7'
# gem 'bh'
# gem 'devise_ldap_authenticatable', '~> 0.8.1'
# gem 'highcharts-rails', '~> 4.1', '>= 4.1.9'
# gem 'kaminari-mongoid' #DEPRECATION WARNING: Kaminari Mongoid support has been extracted to a separate gem, and will be removed in the next 1.0 release.
# gem 'mongoid-encrypted-fields', '~> 1.3.3'
# gem 'mongoid-history', '~> 5.1.0'
# gem 'rypt', '0.2.0'
#
#######################################################

group :doc do
  gem 'sdoc', '~> 0.4.0'
end

group :development do
  gem 'overcommit'
  gem 'rubocop', "0.54.0", require: false
  gem 'rubocop-git'
  gem 'web-console', '2.3.0'
end

group :development, :test do
gem 'pry'
  gem 'capistrano', '3.3.5'
  gem 'capistrano-rails', '1.1.6'
  gem 'email_spec', '2.0.0'
  gem 'factory_girl_rails', '4.6.0'
  gem 'forgery'
  gem 'parallel_tests', "2.21.3"
  gem 'railroady', '~> 1.5.2'
  gem 'rspec-rails', '~> 3.4.2'
  gem 'rspec_junit_formatter', '0.2.3'
  gem 'ruby-progressbar', '~> 1.7'
  gem 'spring', '1.6.3'
  gem 'yard', '~> 0.9.5'
  gem 'yard-mongoid', '~> 0.1.0'
end

group :test do
  gem 'action_mailer_cache_delivery', '~> 0.3.7'
  gem 'capybara', '2.6.2'
  gem 'capybara-screenshot'
  gem 'cucumber', '2.3.3'
  gem 'cucumber-rails', '1.4.3', :require => false
  gem 'database_cleaner', '1.5.3'
  gem 'fakeredis', :require => 'fakeredis/rspec'
  gem 'mongoid-rspec', '3.0.0'
  gem 'poltergeist'
  gem 'shoulda-matchers', '3.1.1'
  gem 'simplecov', '0.14.1', :require => false
  gem 'warden'
  gem 'watir'
end

group :production do
  gem 'eye', '0.8.0'
  gem 'newrelic_rpm'
  gem 'unicorn', '~> 4.8.3'
end

path 'components' do
  # rename this to workflow (smh)
  gem 'ui_helpers'
end
