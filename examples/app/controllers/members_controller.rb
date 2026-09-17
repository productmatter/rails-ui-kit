# frozen_string_literal: true

# The demo endpoints behind docs/guides/forms.md. Every controller sample in that guide is a slice
# of this file.
class MembersController < ApplicationController
  layout 'docs'

  before_action :set_member

  def edit; end

  def update
    if @member.update(member_params)
      redirect_to edit_member_path(@member), notice: "#{@member.name} saved.", status: :see_other
    else
      # 422, or Turbo won't render the response: it rejects a 200 answer to a form submission.
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_member
    @member = Member.find(params[:id])
  end

  def member_params
    params.require(:member)
          .permit(:name, :status, :team_id, role_ids: [], address_attributes: [:city])
          .tap { |permitted| permitted[:role_ids] = role_ids_this_user_may_set(permitted[:role_ids]) }
  end

  # A locked choice is carried by a hidden input, and a hidden input can be edited in the browser.
  # So the server decides: whatever arrived for a locked role is dropped, and the member keeps the
  # locked roles they already had.
  def role_ids_this_user_may_set(submitted)
    locked = Role.locked_ids
    (Array(submitted).compact_blank.map(&:to_i) - locked) | (@member.role_ids & locked)
  end
end
