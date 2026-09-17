# frozen_string_literal: true

require 'active_model'

# The Select docs page's round trip as a real form object: Ui::FieldComponent reads the name,
# the errors, the value and required from it, the way it would from an ActiveRecord model
# (ui-field-model-binding § Behavior, item 18). The model name is Trip, so the field stays
# trip[city] / trip_city, which also makes this the custom model_name case.
class DemoTrip
  include ActiveModel::API

  attr_accessor :city

  validates :city, presence: true
  validate :city_available

  def self.model_name
    ActiveModel::Name.new(self, nil, 'Trip')
  end

  private

  # A failure only the server can catch: the browser's required can't know Tokyo is full.
  def city_available
    errors.add(:city, 'is not available this week') if city == 'tokyo'
  end
end
