# frozen_string_literal: true

require 'active_model'

# Stands in for an ActiveRecord model with an enum on the docs site, which runs without a
# database. Ui::SelectComponent only needs what ActiveRecord publishes for an enum: the
# pluralised mapping, in declaration order, and human_attribute_name for each label.
class DemoOrder
  extend ActiveModel::Translation

  def self.statuses
    { 'pending' => 0, 'packed' => 1, 'shipped' => 2, 'delivered' => 3, 'returned' => 4 }
  end
end
