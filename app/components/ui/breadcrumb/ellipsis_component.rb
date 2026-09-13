# frozen_string_literal: true

module Ui
  module Breadcrumb
    # A collapsed run of items. Unlike the separator, this carries meaning --
    # there are hidden crumbs -- so it keeps an accessible name instead of
    # being hidden from assistive tech (rule 4). A caller can override the
    # name for its own aria: { label: }.
    class EllipsisComponent < Ui::Base
      data_slot 'breadcrumb-ellipsis'

      class_variants(base: 'flex size-9 items-center justify-center')

      DEFAULT_LABEL = 'More'

      def call
        content_tag(:li, '…', root_attributes(aria: { label: DEFAULT_LABEL }))
      end
    end
  end
end
