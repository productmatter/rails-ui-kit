# frozen_string_literal: true

require 'active_model'

# The Choices docs page's round trip as a real form object: one association edited as ids and
# one enum-ish single choice, so the page can show a checkbox group and a radio group coming
# back from the server with the model's own errors (ui-choices § Behavior, item 20).
class DemoMembership
  include ActiveModel::API

  attr_accessor :plan
  attr_reader :role_ids

  validates :plan, presence: true
  validate :at_least_one_role

  def self.model_name
    ActiveModel::Name.new(self, nil, 'Membership')
  end

  # What a checkbox group posts: an array of ids with Rails' blank entry in it, which is what
  # ActiveRecord's own ids writer drops before assigning.
  def role_ids=(values)
    @role_ids = Array(values).map(&:to_s).compact_blank
  end

  def initialize(attributes = {})
    @role_ids = []
    super
  end

  private

  def at_least_one_role
    errors.add(:roles, 'needs at least one role') if role_ids.empty?
  end
end
