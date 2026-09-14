# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development, :test do
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  gem 'importmap-rails'
  gem 'propshaft'
  gem 'puma'
  gem 'rubocop', '~> 1.88', require: false
  gem 'sqlite3'
  gem 'tailwindcss-rails'
  gem 'turbo-rails'
end

group :test do
  # require: false -- these are the browser lane's dependencies and must only be
  # loaded by test/application_system_test_case.rb, never by Bundler.require at
  # boot, or they leak into the unit lane. See docs/specs/ui-test-harness/spec.md.
  gem 'axe-core-api', require: false
  gem 'axe-core-capybara', require: false
  gem 'capybara', require: false
  gem 'selenium-webdriver', require: false
end
