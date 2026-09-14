# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative '../examples/config/environment'
require 'minitest/autorun'
require 'view_component/test_helpers'
require 'view_component/test_case'

# A second locale for i18n coverage: the gem ships English only, so a test that wants to prove a
# string actually resolves through I18n (rather than being a coincidental match) switches to :fr
# via I18n.with_locale and asserts against these fixtures, never against config/locales itself.
# :ar is here for one reason -- six plural categories -- and is not a translation of the kit.
I18n.load_path += Dir[File.expand_path('fixtures/locales/*.yml', __dir__)]
I18n.backend.reload!

# ...and a third that nobody wrote: the pseudo-locale, generated from the English chrome, which
# is what makes a hardcoded string and a box that can't take a longer word both visible.
require_relative 'support/pseudo_locale'
PseudoLocale.install!
