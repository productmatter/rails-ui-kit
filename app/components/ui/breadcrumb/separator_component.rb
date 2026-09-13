# frozen_string_literal: true

module Ui
  module Breadcrumb
    # The separator between two crumbs. Always drawn by the component -- never
    # a slot the caller sets -- so every breadcrumb gets exactly one between
    # each pair of items and never a missing or duplicated one (rule 3).
    class SeparatorComponent < Ui::Base
      data_slot 'breadcrumb-separator'

      class_variants(base: '[&>svg]:size-3.5')

      CHEVRON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" ' \
                'stroke-linecap="round" stroke-linejoin="round"><path d="m9 18 6-6-6-6"/></svg>'.html_safe

      def call
        content_tag(:li, CHEVRON, root_attributes(role: 'presentation', aria: { hidden: true }))
      end
    end
  end
end
