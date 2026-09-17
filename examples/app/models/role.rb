# frozen_string_literal: true

require 'active_model'

# The has_many side of docs/guides/forms.md's demo. Owner is locked: the form shows it but a
# member can't grant or remove it there, which is the case the guide's "a locked checkbox is not
# authorization" section is about.
class Role
  include ActiveModel::API

  attr_accessor :id, :name, :locked

  ALL = [
    { id: 1, name: 'Owner', locked: true },
    { id: 2, name: 'Admin', locked: false },
    { id: 3, name: 'Editor', locked: false },
    { id: 4, name: 'Viewer', locked: false }
  ].freeze

  def self.all
    ALL.map { |attributes| new(**attributes) }
  end

  def self.locked_ids
    all.select(&:locked).map(&:id)
  end
end
