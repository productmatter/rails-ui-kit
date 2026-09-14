# frozen_string_literal: true

require 'active_model'

# A stand-in for a model with an ActiveRecord enum. The component needs only the two
# methods ActiveRecord publishes for one -- the pluralised mapping, in declaration order,
# and human_attribute_name for the label -- so Select renders an enum without the kit
# depending on ActiveRecord at all.
class TestOrder
  extend ActiveModel::Translation

  def self.statuses
    { 'pending' => 0, 'shipped' => 1, 'delivered' => 2 }
  end
end
