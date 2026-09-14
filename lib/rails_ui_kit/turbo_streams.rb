# frozen_string_literal: true

module RailsUiKit
  # The kit's custom Turbo Stream actions, mixed into Turbo's own tag builder through its
  # :turbo_streams_tag_builder load hook (see Engine).
  module TurboStreams
    # The container id the kit's guide puts in the layout. Pass another where the modal lives
    # somewhere else: turbo_stream.ui_close_modal "drawer".
    DEFAULT_TARGET = 'modal'

    # Closes the kit modal inside <tt>target</tt> with its exit animation, leaving the container
    # in place for the next modal. The server closing the modal it opened is the primary close
    # for a successful submission: it is the side that knows the change was accepted, and the
    # same response updates every other region that changed.
    #
    #   <%= turbo_stream.ui_close_modal %>
    #   <%= turbo_stream.ui_close_modal "drawer" %>
    #
    # It does nothing when no modal is open, so it is safe alongside ui--modal#closeOnSuccess.
    def ui_close_modal(target = DEFAULT_TARGET)
      action :ui_close_modal, target, allow_inferred_rendering: false
    end
  end
end
