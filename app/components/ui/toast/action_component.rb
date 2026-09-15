# frozen_string_literal: true

module Ui
  module Toast
    # Renders one toast action through Ui::ButtonComponent, so it carries Button's tokens, focus
    # outline and contrast (ui-toast § Behavior, item 6). The toast container renders the same
    # component, per kind and variant, as the <template>s JavaScript clones, which is what keeps a
    # JavaScript-built action identical to a Ruby-rendered one.
    class ActionComponent < ViewComponent::Base
      # A blank action of each kind, for a template. JavaScript writes its label, href, form
      # action, _method and dismiss flag.
      Blank = Struct.new(:kind, :variant, :label, :href, :http_method, :css_class, :dismiss)

      def self.template(kind, variant)
        new(Blank.new(kind, variant, '', '#', '', nil, true), template: true)
      end

      def initialize(action, template: false)
        super()
        @action = action
        @template = template
      end

      def call
        case @action.kind
        when :link then render(button(href: @action.href))
        when :button then render(button(type: 'button'))
        when :form then form
        end
      end

      private

      # A button_to-shaped form rather than a data-turbo-method link: it is announced as a button,
      # it fails as a rejected POST rather than a GET when Turbo is absent, and it is the form Turbo
      # would build from such a link anyway. Turbo sends the CSRF header itself, so no token field
      # is rendered, from any entry point.
      def form
        tag.form(method: 'post', action: @template ? '' : @action.href, class: 'contents',
                 data: { turbo: 'true', slot: 'toast-action-form' }) do
          safe_join([method_field, render(button(type: 'submit'))].compact)
        end
      end

      def method_field
        return if !@template && @action.http_method == 'post'

        tag.input(type: 'hidden', name: '_method', value: @template ? '' : @action.http_method, autocomplete: 'off')
      end

      def button(**element)
        Ui::ButtonComponent.new(variant: @action.variant, size: :sm, class: @action.css_class,
                                data: { action: 'click->ui--toast#activate', 'ui--toast-dismiss-param': @action.dismiss },
                                **element).with_content(@action.label)
      end
    end
  end
end
