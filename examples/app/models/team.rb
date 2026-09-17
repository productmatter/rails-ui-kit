# frozen_string_literal: true

require 'active_model'

# The belongs_to side of docs/guides/forms.md's demo.
class Team
  include ActiveModel::API

  attr_accessor :id, :name

  ALL = [{ id: 1, name: 'Design' }, { id: 2, name: 'Engineering' }, { id: 3, name: 'Growth' }].freeze

  def self.all
    ALL.map { |attributes| new(**attributes) }
  end
end
