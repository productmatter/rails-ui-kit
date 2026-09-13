# frozen_string_literal: true

module Ui
  module Empty
    # Exposed on Ui::EmptyComponent as `with_body` -- `content` is ViewComponent's
    # block, so the shadcn Content part is renamed at the API, not in its markup
    # (rule 3). Free-form: actions, links, whatever the empty state needs.
    class ContentComponent < Ui::Base
      data_slot 'empty-content'

      class_variants(base: 'flex w-full max-w-sm min-w-0 flex-col items-center gap-4 text-sm text-balance')

      def call
        content_tag(:div, content, root_attributes)
      end
    end
  end
end
