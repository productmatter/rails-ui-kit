# frozen_string_literal: true

class DocsController < ApplicationController
  layout 'docs'

  # One no-op action per registry entry -- add a page to DocsPages::PAGES and it
  # renders here automatically. Give an action real logic by defining it normally
  # below (as modal_demo/demo_submit/demo_delete do); a def after this loop wins.
  DocsPages::PAGES.each do |page|
    define_method(DocsPages.action_for(page)) {}
  end

  def modal_demo
    @position = (params[:position] || "center").to_sym
    respond_to do |format|
      format.turbo_stream
    end
  end

  # The Select docs page's server round trip. A blank city comes back as a 422 with the error on
  # the Field, which is what a real Rails validation failure renders; anything else comes back
  # with the submitted value selected.
  def select_submit
    city = params.dig(:trip, :city).to_s
    errors = { city: select_city_error(city) }.compact
    render partial: 'docs/select_round_trip',
           locals: { errors: errors, values: { city: city }, cities: DocsController.cities,
                     submission: next_select_submission },
           status: errors.any? ? :unprocessable_entity : :ok
  end

  # The result element survives every response, so it carries which response drew it. A reader
  # that lands before the new one has arrived then sees the old number rather than silently
  # matching the old text.
  def next_select_submission
    self.class.select_submissions = self.class.select_submissions.to_i + 1
  end

  # Two server-side failures a client can't catch for itself: nothing chosen, which only a
  # browser with JavaScript off can post at all since the select is required, and a city the
  # server won't take.
  def select_city_error(city)
    return ["can't be blank"] if city.blank?

    ['is not available this week'] if city == 'tokyo'
  end

  class << self
    attr_accessor :select_submissions
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
