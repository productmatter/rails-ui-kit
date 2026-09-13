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

  def demo_submit
    sleep 1.5
    head :no_content
  end

  def demo_delete
    head :no_content
  end
end
