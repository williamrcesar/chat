require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Chat
  class Application < Rails::Application
    config.load_defaults 7.2
    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "America/Sao_Paulo"
    config.i18n.default_locale = :"pt-BR"

    # Use Sidekiq for background jobs
    config.active_job.queue_adapter = :sidekiq

    # Autoload blueprints directory
    config.autoload_paths += [ Rails.root.join("app/blueprints") ]
  end
end
