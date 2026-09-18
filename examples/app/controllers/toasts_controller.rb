# frozen_string_literal: true

# The Toast page's demo endpoints, one per entry point a host uses: a Turbo Stream response, a
# flash that crosses a redirect, and the endpoint an action's form submits to.
class ToastsController < ApplicationController
  # Named payloads, so the docs page and the browser lane send exactly the same data through
  # every entry point.
  SCENARIOS = {
    'archived' => {
      type: 'success', title: 'Project archived', description: 'It no longer appears in your project list.',
      actions: [
        { label: 'View', href: '/demos/projects/1' },
        { label: 'Undo', href: '/demos/toasts/undo', method: 'patch' }
      ]
    },
    'timed' => { type: 'info', description: 'Your export is ready.', duration: 4000, icon: false },
    'saved' => { type: 'success', description: 'Record saved.' }
  }.freeze

  def self.scenario(name)
    SCENARIOS.fetch(name.to_s) { SCENARIOS['saved'] }
  end

  def create
    render turbo_stream: turbo_stream.ui_toast(self.class.scenario(params[:scenario]))
  end

  # A flash survives exactly one redirect, which is how a toast reaches the next page.
  def flash_toast
    flash[:toast] = self.class.scenario(params[:scenario]).deep_stringify_keys if params[:scenario]
    flash[:notice] = params[:notice] if params[:notice]
    flash[:alert] = params[:alert] if params[:alert]
    redirect_to toast_path
  end

  # Answers the Undo action. Turbo sends the CSRF token as a header from the page's meta tag; the
  # toast that comes back says whether it arrived, so the browser lane can see it.
  def undo
    # The header itself, checked directly, so this proves what Turbo sent whatever the app's
    # forgery-protection setting.
    verified = request.patch? && request.x_csrf_token.present? && valid_authenticity_token?(session, request.x_csrf_token)
    render turbo_stream: turbo_stream.ui_toast(type: verified ? 'success' : 'error',
                                               description: verified ? 'Undone: PATCH with a valid CSRF token.' : 'Undo refused.'),
           status: verified ? :ok : :unprocessable_entity
  end
end
