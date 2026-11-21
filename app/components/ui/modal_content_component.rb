# frozen_string_literal: true

module Ui
  # What goes inside a Ui::ModalComponent: a header, a body and a footer, as one turbo frame.
  #
  # The modal is the wrapper, mounted once; this is its content, and every later server
  # response -- a 422, the next step, an in-modal link -- replaces this frame, never the modal
  # (ui-modal-content § Intent). The root is always the <turbo-frame>, so the same component
  # renders inside the modal on open and on its own for every response after, and the frame id
  # can't differ between the two.
  #
  #   <%= render Ui::ModalComponent.new(aria: { labelledby: content.title_id }) do %>
  #     <%= render content do |modal| %> ... <% end %>
  #   <% end %>
  class ModalContentComponent < Ui::Base
    data_slot 'modal-content'

    # Inline by default, a turbo-frame becomes a flex column that fills a full-height dialog
    # (:right, :left are h-dvh) and takes its natural height in any other (§ Behavior, item 6).
    class_variants(base: 'flex min-h-full flex-col')

    # Each the default a matching *_class: keyword merges onto. The header and footer stick to
    # the dialog's own scroll box, on the dialog's background, so content scrolls under them. The
    # footer's bottom padding grows into a phone's home-indicator inset where there is one, and is
    # the same 1rem as its top everywhere else.
    DEFAULT_CLASSES = {
      header: 'sticky top-0 z-10 flex items-start justify-between gap-4 border-b border-border ' \
              'bg-popover px-6 py-4',
      body: 'flex-1 px-6 py-5',
      footer: 'sticky bottom-0 z-10 flex flex-wrap items-center justify-end gap-2 border-t border-border ' \
              'bg-popover px-6 pt-4 pb-[max(1rem,env(safe-area-inset-bottom))]'
    }.freeze

    CLASS_KEYWORDS = DEFAULT_CLASSES.keys.to_h { |part| [:"#{part}_class", part] }.freeze

    # The link in the chain between the frame and the body when there is a form.
    FORM_CLASSES = 'flex flex-1 flex-col'
    TITLE_CLASSES = 'text-base font-semibold text-popover-foreground'
    DESCRIPTION_CLASSES = 'mt-1 text-sm text-muted-foreground'

    include Ui::Chrome
    include Ui::Glyphs

    # The close button's accessible name: chrome, under the modal it closes.
    chrome_string :close_label, key: 'modal.close_label'

    # Replaces the default heading and close button, inside the sticky header.
    renders_one :header
    # The actions, in the sticky footer. No footer is rendered without it.
    renders_one :footer

    attr_reader :id, :title, :description, :form

    def initialize(id:, title: nil, description: nil, close: true, close_label: nil, form: nil, **options)
      @id = id
      @title = title
      @description = description
      @close = close
      @close_label = close_label
      @form = form
      @class_overrides = CLASS_KEYWORDS.filter_map do |keyword, part|
        [part, options.delete(keyword)] if options.key?(keyword)
      end.to_h
      super(**options)
    end

    # The heading's id, so the modal can be named by it in every state:
    #   Ui::ModalComponent.new(aria: { labelledby: content.title_id })
    def title_id
      "#{id}_title"
    end

    def close?
      @close
    end

    def header_shown?
      header? || title.present? || description.present? || close?
    end

    def classes_for(part)
      MERGER.merge([DEFAULT_CLASSES.fetch(part), @class_overrides[part]].compact.join(' '))
    end

    def frame_attributes
      root_attributes(id: id)
    end

    # The caller's form_with options, with ui--form-change joined onto any controller it names,
    # so Ui::ModalComponent's track_changes: works with no extra wiring (§ Behavior, item 4).
    def form_options
      options = form.to_h.symbolize_keys
      data = options.fetch(:data, {}).to_h.symbolize_keys
      data[:controller] = join_tokens('ui--form-change', data[:controller])
      options.merge(data: data, class: MERGER.merge([FORM_CLASSES, options[:class]].compact.join(' ')))
    end

    def close_button
      Ui::ButtonComponent.new(variant: :ghost, size: :icon, class: '-my-1 -me-2',
                              aria: { label: close_label }, data: { action: 'click->ui--modal#close' })
    end

    def close_glyph
      render_glyph(safe_join([tag.path(d: 'M18 6 6 18'), tag.path(d: 'm6 6 12 12')]))
    end
  end
end
