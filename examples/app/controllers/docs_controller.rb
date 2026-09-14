# frozen_string_literal: true

class DocsController < ApplicationController
  layout 'docs'

  # One no-op action per registry entry -- add a page to DocsPages::PAGES and it
  # renders here automatically. Give an action real logic by defining it normally
  # below (as modal_demo/demo_submit/demo_delete do); a def after this loop wins.
  DocsPages::PAGES.each do |page|
    define_method(DocsPages.action_for(page)) {}
  end

  # The Modal + Turbo guide's page. Its demo endpoints live in ProjectsController and
  # InvitationsController, the way a host app's would; this only lists the records.
  def modal_turbo
    @projects = Project.all
  end

  def modal_demo
    @position = (params[:position] || "center").to_sym
    respond_to do |format|
      format.turbo_stream
    end
  end

  # The Select docs page's server round trip. A blank city, or one the server won't take, comes
  # back as a 422 with the model's error on the Field, which is what a real Rails validation
  # failure renders; anything else comes back with the submitted value selected.
  def select_submit
    trip = DemoTrip.new(city: params.dig(:trip, :city).to_s)
    valid = trip.valid?
    render partial: 'docs/select_round_trip',
           locals: { trip: trip, cities: DocsController.cities, submission: next_select_submission },
           status: valid ? :ok : :unprocessable_entity
  end

  # The result element survives every response, so it carries which response drew it. A reader
  # that lands before the new one has arrived then sees the old number rather than silently
  # matching the old text.
  def next_select_submission
    self.class.select_submissions = self.class.select_submissions.to_i + 1
  end

  # The Field docs page's help-text swap. A form in a frame re-renders by replacing the field, which
  # leaves nothing to animate from; answering with a morphing stream keeps the field and lets the
  # description and the error swap in place (ui-field-model-binding § Behavior, item 21). With
  # JavaScript off the same partial comes back as HTML.
  def field_submit
    signup = DemoSignup.new(username: params.dig(:signup, :username).to_s)
    status = signup.valid? ? :ok : :unprocessable_entity
    locals = { signup: signup, submission: self.class.field_submissions = self.class.field_submissions.to_i + 1 }

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace('field-swap-demo', partial: 'docs/field_swap_demo', locals: locals, method: :morph),
               status: status
      end
      format.html { render partial: 'docs/field_swap_demo', locals: locals, status: status }
    end
  end

  class << self
    attr_accessor :select_submissions, :field_submissions
  end

  def self.cities
    [['Berlin', 'berlin'], ['Lisbon', 'lisbon'], ['London', 'london'], ['Tokyo', 'tokyo']]
  end

  def demo_submit
    sleep 1.5
    head :no_content
  end

  def demo_delete
    head :no_content
  end
end
