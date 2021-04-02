require_relative 'boot'

require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'rails/test_unit/railtie'
require 'sprockets/railtie'
require 'identity/logging/railtie'

require_relative '../lib/app_config_reader'
require_relative '../lib/app_config'
require_relative '../lib/identity_config'
require_relative '../lib/fingerprinter'
require_relative '../lib/identity_job_log_subscriber'

Bundler.require(*Rails.groups)

APP_NAME = 'login.gov'.freeze

module Upaya
  class Application < Rails::Application
    configuration = AppConfigReader.new.read_configuration(
      write_copy_to: Rails.root.join('tmp', 'application.yml'),
    )

    AppConfig.setup(configuration)

    root_config = configuration.except(['development', 'production', 'test'])
    environment_config = root_config[Rails.env]
    merged_config = root_config.merge(environment_config)
    merged_config.symbolize_keys!

    IdentityConfig.build_store(merged_config)

    config.load_defaults '6.1'
    config.active_record.belongs_to_required_by_default = false
    config.assets.unknown_asset_fallback = true

    if AppConfig.env.ruby_workers_enabled == 'true'
      config.active_job.queue_adapter = :delayed_job
    else
      config.active_job.queue_adapter = :inline
    end
    config.time_zone = 'UTC'

    # Generate CSRF tokens that are encoded in URL-safe Base64.
    #
    # This change is not backwards compatible with earlier Rails versions.
    # It's best enabled when your entire app is migrated and stable on 6.1.
    Rails.application.config.action_controller.urlsafe_csrf_tokens = false

    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{yml}')]
    config.i18n.available_locales = %w[en es fr]
    config.i18n.default_locale = :en
    config.action_controller.per_form_csrf_tokens = true

    routes.default_url_options[:host] = AppConfig.env.domain_name

    config.action_mailer.default_options = {
      from: Mail::Address.new.tap do |mail|
        mail.address = AppConfig.env.email_from
        mail.display_name = AppConfig.env.email_from_display_name
      end.to_s,
    }

    require 'headers_filter'
    config.middleware.insert_before 0, HeadersFilter
    require 'utf8_sanitizer'
    config.middleware.use Utf8Sanitizer

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins do |source, _env|
          next if source == AppConfig.env.domain_name

          ServiceProvider.pluck(:redirect_uris).flatten.compact.find do |uri|
            split_uri = uri.split('//')
            protocol = split_uri[0]
            domain = split_uri[1].split('/')[0] if split_uri.size > 1
            source == "#{protocol}//#{domain}"
          end.present?
        end
        resource '/.well-known/openid-configuration', headers: :any, methods: [:get]
        resource '/api/openid_connect/certs', headers: :any, methods: [:get]
        resource '/api/openid_connect/token',
                 credentials: true,
                 headers: :any,
                 methods: %i[post options]
        resource '/api/openid_connect/userinfo', headers: :any, methods: [:get]
      end
    end

    if AppConfig.env.enable_rate_limiting == 'true'
      config.middleware.use Rack::Attack
    else
      # Rack::Attack auto-includes itself as a Railtie, so we need to
      # explicitly remove it when we want to disable it
      config.middleware.delete Rack::Attack
    end
  end
end
