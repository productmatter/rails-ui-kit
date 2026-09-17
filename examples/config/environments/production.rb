# frozen_string_literal: true

require 'active_support/core_ext/integer/time'

# The public docs site on Fly.io (examples/DEPLOY.md). Rails 8.1's generated production config,
# less everything this app doesn't have: no database, jobs, mail or storage.
Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # Nothing sits in front of the app but Fly's proxy and Thruster, so Rails serves the compiled
  # assets; their digested names make a year-long cache safe.
  config.public_file_server.enabled = true
  config.public_file_server.headers = { 'cache-control' => "public, max-age=#{1.year.to_i}" }

  # Fly terminates TLS, forwards plain HTTP, and redirects http:// itself (force_https in
  # fly.toml); force_ssl adds HSTS and secure cookies.
  config.assume_ssl = true
  config.force_ssl = true

  # <app>.fly.dev from the FLY_APP_NAME Fly sets on every machine, so the app name lives only in
  # fly.toml; RAILS_HOSTS (comma-separated) adds a custom domain, or localhost for a local run.
  config.hosts = [
    ("#{ENV['FLY_APP_NAME']}.fly.dev" if ENV['FLY_APP_NAME']),
    *ENV.fetch('RAILS_HOSTS', '').split(',').map(&:strip)
  ].compact_blank
  config.host_authorization = { exclude: ->(request) { request.path == '/up' } }

  # SECRET_KEY_BASE comes from the environment (a Fly secret); Rails raises if it's missing.
  # assets:precompile runs with SECRET_KEY_BASE_DUMMY=1 instead.

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')
  config.silence_healthcheck_path = '/up'
  config.active_support.report_deprecations = false
end
