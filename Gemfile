# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# json 3 breaks every Rails release up to and including 8.1.3.1: 7.2 and 8.0 raise `unknown keyword:
# quirks_mode` from their JSON encoder, and 8.1.3.1's ActiveSupport::JSON.decode passes JSON.parse
# a positional options hash json 3 rejects, so reading any signed or encrypted cookie raises
# (UPGRADING.md). Before Gemfile.lock was tracked the docs image resolved fresh, shipped json 3, and
# 500ed on every form. Pinned here, not in the gemspec: a Rails bug, not a rails_ui_kit constraint.
gem 'json', '< 3'

group :development, :test do
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  gem 'rubocop', '~> 1.88', require: false

  # Gemfile.lock is resolved on the docs image's Ruby (4.0, examples/Dockerfile) but has to install
  # on every Ruby CI runs, down to the kit's 3.2 floor. These two dependencies of the tools above
  # dropped 3.2 in their newest releases; nothing else in the lock excludes it.
  gem 'parallel', '< 2', require: false # rubocop
  gem 'rbs', '< 4.2', require: false # rdoc, via debug
end

# The docs app (examples/) at runtime, installed in its production image as well as here.
# examples/config/application.rb requires this group in every environment.
group :docs do
  gem 'importmap-rails'
  gem 'propshaft'
  gem 'puma'
  gem 'thruster', require: false
  gem 'turbo-rails'
end

# The docs app's Tailwind build. Needed wherever assets are compiled -- development, test, and the
# image's build stage (RAILS_GROUPS=assets) -- but not in the runtime image: the compiled CSS is
# all it serves, and the standalone Tailwind binary is ~75MB.
group :assets do
  gem 'tailwindcss-rails'
end

group :test do
  # require: false -- these are the browser lane's dependencies and must only be
  # loaded by test/application_system_test_case.rb, never by Bundler.require at
  # boot, or they leak into the unit lane. See docs/specs/ui-test-harness/spec.md.
  gem 'axe-core-api', require: false
  gem 'axe-core-capybara', require: false
  gem 'capybara', require: false
  gem 'selenium-webdriver', require: false

  # choices_submission_test.rb's in-memory ActiveRecord. The docs app has no database.
  gem 'sqlite3'
end
