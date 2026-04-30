# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require_relative 'dummy/config/environment'
require 'minitest/autorun'
require 'view_component/test_helpers'
require 'view_component/test_case'
