# frozen_string_literal: true

require 'test_helper'

# turbo_stream.ui_close_modal, the kit's one custom Turbo Stream action. The client half of it
# (the modal actually animating out) is driven in test/system/modal_turbo_success_test.rb.
class TurboStreamUiCloseModalTest < ActionView::TestCase
  def builder
    Turbo::Streams::TagBuilder.new(view)
  end

  test 'renders a ui_close_modal stream targeting the layout container by default' do
    assert_dom_equal '<turbo-stream action="ui_close_modal" target="modal"><template></template></turbo-stream>',
                     builder.ui_close_modal
  end

  test 'targets the container id it is given' do
    assert_dom_equal '<turbo-stream action="ui_close_modal" target="drawer"><template></template></turbo-stream>',
                     builder.ui_close_modal('drawer')
  end

  # allow_inferred_rendering: false. Without it, a target that names a record -- the shape every
  # other action accepts -- sends Turbo looking for a partial to fill a template this action
  # never reads.
  test 'renders an empty template rather than inferring a partial from the target' do
    assert_dom_equal '<turbo-stream action="ui_close_modal" target="project_modal"><template></template></turbo-stream>',
                     builder.ui_close_modal('project_modal')
  end

  test 'the action is namespaced, so it cannot collide with a host app registering close_modal' do
    assert_not_respond_to builder, :close_modal
  end
end
