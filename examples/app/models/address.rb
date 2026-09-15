# frozen_string_literal: true

require 'active_model'

# The nested record in docs/guides/forms.md's demo: what `has_one :address` plus
# `accepts_nested_attributes_for :address` gives a member.
class Address
  include ActiveModel::API

  attr_accessor :city

  validates :city, presence: true
end
