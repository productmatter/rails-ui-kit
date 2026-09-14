# frozen_string_literal: true

require 'active_model'

# The Field docs page's model-bound previews. Email has an unconditional presence validator, so
# its Field is required without being told. Handle has one too, but a callback fills it from
# the email before validation runs, so a blank handle is never rejected: the case where the
# page passes required: false (ui-field-model-binding § Behavior, item 12).
class DemoProfile
  include ActiveModel::API
  include ActiveModel::Validations::Callbacks

  attr_accessor :email, :handle

  validates :email, presence: true
  validates :handle, presence: true

  before_validation { self.handle = email.to_s.split('@').first if handle.blank? }

  def self.model_name
    ActiveModel::Name.new(self, nil, 'Profile')
  end
end
