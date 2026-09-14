# frozen_string_literal: true

# The guide's second demo: a modal form whose success changes nothing else on the page, so the
# response has nothing to render and ui--modal#closeOnSuccess is what closes the modal.
class InvitationsController < ApplicationController
  layout -> { 'docs' unless turbo_frame_request? }

  def new
    @invitation = Invitation.new
  end

  def create
    @invitation = Invitation.new(invitation_params)

    if @invitation.valid?
      # Nothing on the page behind the modal changed, so there is nothing to render. The form's
      # turbo:submit-end->ui--modal#closeOnSuccess closes the modal on this 204.
      head :no_content
    else
      render :new, formats: :html, status: :unprocessable_entity
    end
  end

  private

  def invitation_params
    params.require(:invitation).permit(:email)
  end
end
