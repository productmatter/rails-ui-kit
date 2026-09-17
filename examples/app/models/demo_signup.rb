# frozen_string_literal: true

require 'active_model'

# The Field docs page's swap demo. Its checks are a custom validate, which required detection
# deliberately doesn't read (ui-field-model-binding § Behavior, item 11), so the browser lets a
# blank username through and the server's 422 is what makes the field invalid.
class DemoSignup
  include ActiveModel::API

  TAKEN = %w[admin root].freeze

  attr_accessor :username

  validate :username_acceptable

  def self.model_name
    ActiveModel::Name.new(self, nil, 'Signup')
  end

  private

  def username_acceptable
    if username.blank?
      errors.add(:username, :blank)
    elsif TAKEN.include?(username.downcase)
      errors.add(:username, 'is already taken')
    end
  end
end
