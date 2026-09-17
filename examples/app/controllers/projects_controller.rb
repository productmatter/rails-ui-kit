# frozen_string_literal: true

# The demo endpoints behind docs/guides/modal-and-turbo.md. Every controller sample in that guide
# is a slice of this file, so the guide can't describe a pattern the demos don't run.
class ProjectsController < ApplicationController
  # The docs app's own chrome, and only where the response is a whole page: a Turbo Frame request
  # renders the frame alone. A host app needs neither line -- turbo-rails already answers frame
  # requests with its own minimal layout.
  layout -> { 'docs' unless turbo_frame_request? }

  before_action :set_project

  # Opens the modal: show.turbo_stream.erb updates the layout's <div id="modal">. show.html.erb is
  # the same content as a bare frame, which is what an in-modal "Back" link navigates to.
  def show; end

  def edit; end

  def update
    if @project.update(project_params)
      flash.now[:notice] = "#{@project.name} saved."
      # update.turbo_stream.erb: close the modal, and update every region this change touched.
    else
      # formats: :html, because a form submission asks for Turbo Stream first and `render :edit`
      # would otherwise pick edit.turbo_stream.erb -- the template that *opens* the modal -- and
      # re-mount it over itself. 422, because Turbo rejects a 200 HTML response to a form.
      render :edit, formats: :html, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    flash.now[:notice] = "#{@project.name} deleted."
  end

  # Read-only, and the one demo of the frame-target pattern: it renders into its own
  # <turbo-frame id="project_activity_modal">, never into the layout's shared container.
  def activity; end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :summary)
  end
end
