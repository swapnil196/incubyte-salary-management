source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Builds and serves the React bundle from this same application (ADR 001).
gem "vite_rails", "~> 3.0"

# Used by the seed script, which has to be runnable against the deployed
# instance, so it cannot live in the development group.
gem "faker", "~> 3.5"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  # bin/bundler-audit and the CI security job both depend on this.
  gem "bundler-audit", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.4"
end

group :development do
  # Fails loudly on N+1 queries rather than letting them reach production.
  gem "bullet"
end

group :test do
  gem "shoulda-matchers", "~> 6.4"
  gem "simplecov", require: false
  # Lets specs assert that a query count is what we think it is, so an N+1
  # regression fails the build instead of being noticed in production.
  gem "db-query-matchers", "~> 0.12"
end
