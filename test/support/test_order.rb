# frozen_string_literal: true

require 'active_model'

# A stand-in for a model with an ActiveRecord enum, without ActiveRecord. The component needs
# only what ActiveRecord publishes for one -- the pluralised mapping in declaration order,
# defined_enums for detecting which attribute is an enum, and human_attribute_name for the label
# -- so Select and Choices render and infer an enum without the kit depending on ActiveRecord at
# all. ActiveModel::API, not Translation alone, so it can also be a Field's model: (item 2's
# enum inference): a record with a status to bind to, and a plain note that isn't an enum.
class TestOrder
  include ActiveModel::API

  attr_accessor :status, :note

  def self.statuses
    { 'pending' => 0, 'shipped' => 1, 'delivered' => 2 }
  end

  # What ActiveRecord::Enum publishes on the class (class_attribute :defined_enums): every enum
  # attribute's name, mapped to its values -- how a caller asks "is this attribute an enum"
  # without ActiveRecord.
  def self.defined_enums
    { 'status' => statuses }
  end
end
