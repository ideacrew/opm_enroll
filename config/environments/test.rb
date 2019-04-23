Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true 
  config.cache_store = :memory_store

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = true

  # Configure static file server for tests with Cache-Control for performance.
  config.serve_static_files   = true
  config.static_cache_control = 'public, max-age=3600'

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :cache

  # Randomize the order test cases are executed.
  config.active_support.test_order = :random

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr
  config.action_mailer.cache_settings = { :location => "#{Rails.root}/tmp/cache/action_mailer_cache_delivery#{ENV['TEST_ENV_NUMBER']}.cache" }

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
  config.acapi.app_id = "enroll"
  HbxIdGenerator.slug!
  config.ga_tracking_id = ENV['GA_TRACKING_ID'] || "dummy"
  config.ga_tagmanager_id = ENV['GA_TAGMANAGER_ID'] || "dummy"

  config.action_mailer.default_url_options = {
    :host => "127.0.0.1",
    :port => 3000
  }

  #Environment URL stub
  config.checkbook_services_base_url = Settings.checkbook_services.base_url

  #Queue adapter
  config.active_job.queue_adapter = :test

  Mongoid.logger.level = Logger::ERROR
  Mongo::Logger.logger.level = Logger::ERROR
end
