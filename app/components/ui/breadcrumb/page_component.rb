# frozen_string_literal: true

module Ui
  module Breadcrumb
    # The current page: not a link, and announced through aria-current="page"
    # rather than a bespoke visual treatment alone.
    class PageComponent < Ui::Base
      data_slot 'breadcrumb-page'

      class_variants(base: 'font-normal text-foreground')

      def call
        content_tag(:li, content_tag(:span, content, root_attributes(aria: { current: 'page' })), class: 'inline-flex items-center gap-1.5')
      end
    end
  end
end
