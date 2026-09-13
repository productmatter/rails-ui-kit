# frozen_string_literal: true

module Ui
  module Pagination
    # A page link, rendered through Ui::ButtonComponent -- the outline variant
    # marks the current page, ghost every other -- never a private copy of
    # Button's class table (rule 1). Previous/Next are the same part with
    # icon-only content and their own aria-label; only the current page
    # passes `active: true`. `class:` styles this part's own <li>; every
    # other forwarded attribute (href, aria, data, id) reaches the Button,
    # the element that is actually the link.
    class LinkComponent < Ui::Base
      data_slot 'pagination-link'

      attr_reader :active

      def initialize(active: false, **html_attributes)
        @active = active
        super(**html_attributes)
      end

      def call
        content_tag(:li, button, class: root_class, data: { slot: self.class.data_slot })
      end

      private

      def button
        render(Ui::ButtonComponent.new(variant: active ? :outline : :ghost, size: :icon, **button_attributes)) { content }
      end

      def button_attributes
        return html_attributes unless active

        html_attributes.merge(aria: (html_attributes[:aria] || {}).merge(current: 'page'))
      end
    end
  end
end
