# frozen_string_literal: true

require 'active_model'

# The Character Counter docs page's server round trip. A custom validate, the way
# docs/select and docs/field's own swap demos use one, deliberately not `validates :body,
# presence: true`: an unconditional presence validator would make Field mark the control
# `required`, so the browser's own constraint validation would block a blank submission
# before it ever reached the server -- and reaching the server, with a genuine 422, is the
# whole point of this demo. The check is independent of the counter's soft limit either way
# (ui-character-counter § Behavior, item 5): the counter never validates (§ Business rules,
# rule 1).
class DemoNote
  include ActiveModel::API

  attr_accessor :body

  validate :body_present

  def self.model_name
    ActiveModel::Name.new(self, nil, 'Note')
  end

  private

  def body_present
    errors.add(:body, :blank) if body.blank?
  end
end
