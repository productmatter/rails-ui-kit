# frozen_string_literal: true

class DocsController < ApplicationController
  layout 'docs'

  def index; end
  def installation; end
  def modal; end
  def dropdown; end
  def tooltip; end
  def popover; end
  def toast; end
  def confirm_dialog; end
  def dark_mode; end
  def form_change; end
  def turbo_confirm; end
  def turbo_disable_with; end

  def modal_demo
    @position = (params[:position] || "center").to_sym
    respond_to do |format|
      format.turbo_stream
    end
  end

  def demo_submit
    sleep 1.5
    head :no_content
  end

  def demo_delete
    head :no_content
  end
end
