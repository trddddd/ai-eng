source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Use Redis adapter to run Action Cable in production
gem "redis"

# Use Active Model has_secure_password
gem "bcrypt", "~> 3.1.7"

# Spaced repetition algorithm FSRS (open-spaced-repetition/rb-fsrs)
gem "fsrs", github: "open-spaced-repetition/rb-fsrs"

# Load .env in development/test (DB_HOST, DB_PORT, etc.)
gem "dotenv-rails", groups: %i[development test]

# CSV parsing (moved out of default gems in Ruby 3.4)
gem "csv"

# Locale data for Rails i18n (includes ActiveRecord translations for :ru)
gem "rails-i18n"

# Error tracking
gem "sentry-rails"
gem "sentry-ruby"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "factory_bot_rails"
  gem "rspec-rails"
end

group :test do
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "web-console"
  # WordNet 3.1 for sense data import (ADR-001)
  gem "wordnet"
  gem "wordnet-defaultdb"
end
