# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'action_cable/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
# require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module ReviewBalancer
  class Application < Rails::Application
    config.load_defaults 7.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.active_job.queue_adapter = :sidekiq
    config.middleware.use Rack::Attack

    config.i18n.available_locales = %i[es en]
    config.i18n.default_locale = :es
  end
end
