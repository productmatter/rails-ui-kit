# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative '../examples/config/environment'
require 'minitest/autorun'
require 'view_component/test_helpers'
require 'view_component/test_case'

# A second locale for i18n coverage: the gem ships English only, so a test that wants to prove a
# string actually resolves through I18n (rather than being a coincidental match) switches to :fr
# via I18n.with_locale and asserts against these fixtures, never against config/locales itself.
I18n.load_path += Dir[File.expand_path('fixtures/locales/*.yml', __dir__)]
I18n.backend.reload!
