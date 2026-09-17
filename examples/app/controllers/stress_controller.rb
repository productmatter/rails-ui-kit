# frozen_string_literal: true

# The stress page (docs/specs/ui-stress-page): the whole kit on one page, in a host's layout, for
# the browser lane to collide. A fixture, not documentation.
class StressController < ApplicationController
  layout 'stress'

  helper_method :page_params, :turbo_off?, :render_token

  # A toast with an action persists by default, so F8 reaches it without racing a countdown.
  SAVED_TOAST = { type: 'success', description: 'Stress record saved.',
                  actions: [{ label: 'Dismiss', variant: 'ghost' }] }.freeze

  NOTIFY_TOAST = { type: 'info', description: 'Notification sent.', actions: [{ label: 'Dismiss', variant: 'ghost' }] }.freeze

  STREAMS = {
    'status_field' => ->(streams) { streams.replace('page-status-field', partial: 'stress/status_field', locals: { prefix: 'page' }) },
    'cluster' => ->(streams) { streams.replace('page-cluster', partial: 'stress/overlay_cluster', locals: { prefix: 'page' }) },
    'modal' => ->(streams) { streams.update('stress-modal', partial: 'stress/modal') },
    'city_field' => ->(streams) { streams.replace('modal-city-field', partial: 'stress/city_field') },
    'refresh' => ->(streams) { streams.refresh(request_id: nil) }
  }.freeze

  class << self
    attr_accessor :renders
  end

  def show
    @record = StressRecord.new
  end

  def create
    @record = StressRecord.new(record_params)
    return render(:show, status: :unprocessable_entity) unless @record.valid?

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.ui_toast(SAVED_TOAST) }
      format.html do
        flash[:toast] = SAVED_TOAST.deep_stringify_keys
        redirect_to stress_path(page_params), status: :see_other
      end
    end
  end

  def bare; end

  def modal; end

  # The toast a Modal's button, and its confirmed form, answer with.
  def toast
    render turbo_stream: turbo_stream.ui_toast(NOTIFY_TOAST)
  end

  # Real server responses for the replace-while-open sequences (§ Behavior, item 13), each started
  # from a script so nothing on the page is clicked to start it.
  def stream
    render turbo_stream: STREAMS.fetch(params[:target]) { raise ActionController::RoutingError, params[:target] }
                                .call(turbo_stream)
  end

  private

  # The condition parameters a render carries forward (§ Behavior, item 5).
  def page_params
    request.query_parameters.slice('locale', 'turbo')
  end

  def turbo_off?
    params[:turbo] == 'off'
  end

  # A value only this render produces, so a test waits on a re-render rather than reading an
  # element that already held the previous one (§ Business rules, rule 5).
  def render_token
    @render_token ||= self.class.renders = self.class.renders.to_i + 1
  end

  def record_params
    params.fetch(:stress_record, {}).permit(:name, :notes, :plan, :city, :frequency, channel_ids: [])
  end
end
