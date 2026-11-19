# frozen_string_literal: true

# Usado por jobs (Web Push) e mailer para gerar URLs absolutas.
Rails.application.config.after_initialize do
  host = ENV.fetch("APP_HOST", "localhost")
  port = ENV.fetch("APP_PORT", "3000").to_s
  opts = { host: host }
  opts[:port] = port if port != "80" && port != "443"
  Rails.application.routes.default_url_options.merge!(opts)
end
