# frozen_string_literal: true

require 'active_model'

# The demo resource behind the guide's "a success response with nothing to render" section: a
# form whose success changes nothing on the page behind the modal, so there is no stream to send
# and ui--modal#closeOnSuccess is what closes it. Nothing is stored -- sending an invitation is
# the whole action.
class Invitation
  include ActiveModel::API

  attr_accessor :email

  validates :email, presence: true
  # A failure only the server can catch: <input type="email"> is happy with "sam@example", so
  # the address is checked where it has to be checked anyway.
  validates :email, format: { with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/, message: 'must be a valid address' },
                    allow_blank: true
end
