Rails.application.config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE") {
  Rails.env.production? ? :cloudflare_r2 : :local
}.to_sym
