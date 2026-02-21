source "https://rubygems.org"

gem "rails", "~> 8.1.2"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "jbuilder"
gem "redis", ">= 4.0.1"
gem "image_processing", "~> 1.2"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Authentication
gem "devise"
gem "devise-jwt"

# Authorization
gem "pundit"

# Pagination
gem "pagy"

# Background jobs
gem "sidekiq"

# Storage (Cloudflare R2 / S3-compatible)
gem "aws-sdk-s3", require: false

# Environment variables
gem "dotenv-rails"

# API serialization
gem "blueprinter"

# Full-text search
gem "pg_search"

# CORS for API
gem "rack-cors"

# Web Push Notifications (PWA)
gem "webpush"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
