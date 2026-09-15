# frozen_string_literal: true

require 'active_model'

# The stress page's form object (docs/specs/ui-stress-page § Behavior, item 3). Nothing is saved:
# it exists so each form control is bound to a record, rendered back with the record's errors on
# a 422, and required because a presence validator says so.
class StressRecord
  include ActiveModel::API

  City = Struct.new(:id, :name)
  Channel = Struct.new(:id, :name, :tagline)

  CITIES = [City.new('lisbon', 'Lisbon'), City.new('london', 'London'), City.new('paris', 'Paris'),
            City.new('tokyo', 'Tokyo'), City.new('toronto', 'Toronto')].freeze
  FREQUENCIES = [%w[Daily daily], %w[Weekly weekly], %w[Monthly monthly]].freeze
  CHANNELS = [Channel.new('email', 'Email', 'A digest in your inbox.'),
              Channel.new('sms', 'SMS', 'A text for anything urgent.'),
              Channel.new('push', 'Push', 'A notification on your devices.')].freeze

  attr_accessor :name, :notes, :plan, :city, :frequency
  attr_reader :channel_ids

  # What `enum :plan, { starter: 0, growth: 1, scale: 2 }` publishes.
  def self.plans
    { 'starter' => 0, 'growth' => 1, 'scale' => 2 }
  end

  validates :name, presence: true
  validates :channel_ids, presence: true

  def initialize(attributes = {})
    @channel_ids = []
    super
  end

  # What a checkbox group posts: ids as strings, with Rails' blank entry, which is dropped.
  def channel_ids=(values)
    @channel_ids = Array(values).compact_blank
  end
end
