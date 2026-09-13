# frozen_string_literal: true

module Ui
  module Breadcrumb
    # A crumb that links to an ancestor page. The <li> is plain, structural
    # markup; the <a> is the part, and carries whatever the caller forwards
    # (href, aria, data, id). The focus indicator is drawn the same way Button
    # draws it (rule 4) -- this <a> is a real link, not a Button, so it needs
    # its own copy of the outline classes rather than inheriting Button's.
    class LinkComponent < Ui::Base
      data_slot 'breadcrumb-link'

      class_variants(
        base: 'rounded-xs transition-colors hover:text-foreground ' \
              'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring'
      )

      def call
        content_tag(:li, content_tag(:a, content, root_attributes), class: 'inline-flex items-center gap-1.5')
      end
    end
  end
end
