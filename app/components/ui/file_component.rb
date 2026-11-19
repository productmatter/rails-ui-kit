# frozen_string_literal: true

module Ui
  # A file control: a drop area while nothing is chosen ("Drop a PDF here or Choose PDF", and one
  # meta line the caller writes), collapsing to a file row once something is (a file glyph, the
  # name, the caller's meta -- size, pages -- and a quiet "Change").
  #
  # The native <input type="file"> is the control, and the only one. It is laid over the whole box,
  # transparent, so a press anywhere opens the platform picker and a file dropped anywhere is the
  # browser's own drop onto a file input: picking, dropping, `required`, `accept`, submission and
  # the Field label's `for` are all the platform's, and all work with JavaScript off. It is the one
  # tab stop; its focus, invalid and disabled states draw on the visible box through `:has()`. The
  # "Choose" and "Change" buttons under it are what a sighted user reads as the affordance, so they
  # are aria-hidden and out of the tab order rather than a second way to reach the same control.
  #
  # `ui--file` does the three things only script can: it swaps the drop area for the file row once
  # a file is chosen, shows the drop target while a file is dragged over it, and refuses a dropped
  # file `accept:` doesn't allow -- a browser applies `accept` to its picker only, never to a drop.
  class FileComponent < Ui::Base
    include Ui::Chrome
    include Ui::Glyphs

    data_slot 'file'

    # The aria that names, describes or invalidates the control follows it onto the input, as
    # Select's does onto whichever element plays its control (Ui::SelectComponent::CONTROL_ARIA).
    CONTROL_ARIA = %i[describedby invalid label labelledby].freeze

    # The box, shared by both states: the control boundary and fill, as Input's. Focus, invalid and
    # disabled are read from the input inside it. The drop area is dashed -- the convention for "a
    # place to put something" -- and solid once it holds a file.
    BOX = 'relative rounded-md border border-input bg-background dark:bg-muted/50 shadow-xs transition-colors ' \
          'has-[input:focus-visible]:border-ring has-[input:focus-visible]:outline-2 has-[input:focus-visible]:outline-ring ' \
          'has-[input[aria-invalid=true]]:border-destructive ' \
          'has-[input[aria-invalid=true]:focus-visible]:outline-destructive ' \
          'has-[input:disabled]:opacity-50'

    # Laid over the whole box, transparent but rendered: a browser can't open a picker for, or
    # report invalid, an input it doesn't render.
    INPUT = 'absolute inset-0 z-10 size-full cursor-pointer opacity-0 disabled:cursor-not-allowed ' \
            'file:cursor-pointer disabled:file:cursor-not-allowed'

    class_variants(
      base: "group/file #{BOX} border-dashed data-[state=chosen]:border-solid " \
            'data-[dragging=true]:border-primary data-[dragging=true]:bg-accent'
    )

    # The words the control says in its own voice. Generic by default -- "Choose file" -- and a call
    # site that knows what it takes says so per instance: `choose_label: "Choose PDF"`.
    chrome_string :drop_label, key: 'file.drop_label'
    chrome_string :choose_label, key: 'file.choose_label'
    chrome_string :change_label, key: 'file.change_label'

    attr_reader :name, :control_id, :meta, :filename, :file_meta

    # `meta:` is the drop area's one line ("PDF, up to 20 MB"). `filename:` and `file_meta:` render
    # the control already holding a file -- the one the record has, on an edit form -- as the file
    # row; choosing another replaces them, and a form reset puts them back.
    def initialize(name:, id: nil, accept: nil, required: false, disabled: false, form: nil, meta: nil,
                   filename: nil, file_meta: nil, drop_label: nil, choose_label: nil, change_label: nil,
                   **attributes)
      @name = name.to_s
      @control_id = (id || derive_control_id).to_s
      @accept = accept
      @required = boolean_attribute?(required)
      @disabled = boolean_attribute?(disabled)
      @form = form
      assign_content(meta: meta, filename: filename, file_meta: file_meta)
      assign_chrome(drop_label: drop_label, choose_label: choose_label, change_label: change_label)
      super(**attributes)
      extract_control_aria!
    end

    def chosen?
      filename.present?
    end

    def wrapper_attributes
      root_attributes(data: { controller: 'ui--file', state: chosen? ? 'chosen' : 'empty',
                              action: 'dragenter->ui--file#dragenter dragover->ui--file#dragover ' \
                                      'dragleave->ui--file#dragleave drop->ui--file#drop',
                              'ui--file-locale-value': chrome_locale })
    end

    def input_attributes
      { type: 'file', id: control_id, name: name, accept: @accept, required: (true if @required),
        disabled: (true if @disabled), form: @form, class: INPUT, aria: input_aria.presence,
        data: { 'ui--file-target': 'input', action: 'change->ui--file#render' } }.compact
    end

    # What the box shows in words, read as part of the input's description: the drop area's meta
    # line, or the file row's name and meta -- the file a record already has is not in the input, so
    # this is the only way a screen reader hears it. One of the two at a time, after the Field's own
    # ids; ui--file swaps it with the state.
    def meta_id
      "#{control_id}-meta"
    end

    def file_id
      "#{control_id}-file"
    end

    # The two Buttons under the input. Never a second control: hidden from the accessibility tree,
    # out of the tab order, and under the input, which takes every press. Their hover is the box's.
    def affordance_attributes(hover)
      { tabindex: -1, aria: { hidden: true }, class: "pointer-events-none #{hover}" }
    end

    # A disabled control's text is exempt from contrast (WCAG 1.4.3), and its dimmed parts say so, so
    # a checker reads them as the disabled control they belong to rather than as body text.
    def part_aria
      { disabled: ('true' if @disabled) }.compact
    end

    def render_upload_glyph
      render_glyph(safe_join([tag.path(d: 'M12 3v12'), tag.path(d: 'm17 8-5-5-5 5'),
                              tag.path(d: 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4')]),
                   css: 'size-5 text-muted-foreground')
    end

    def render_file_glyph
      render_glyph(safe_join([tag.path(d: 'M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z'),
                              tag.path(d: 'M14 2v4a2 2 0 0 0 2 2h4'), tag.path(d: 'M10 13h4'), tag.path(d: 'M10 17h4')]),
                   css: 'size-4')
    end

    private

    def input_aria
      state_id = chosen? ? file_id : (meta_id if meta.present?)
      described = [@control_aria[:describedby], state_id].compact.join(' ').presence
      @control_aria.merge(describedby: described).compact
    end

    def assign_content(meta:, filename:, file_meta:)
      @meta = meta
      @filename = filename.to_s.presence
      @file_meta = file_meta
    end

    def assign_chrome(drop_label:, choose_label:, change_label:)
      @drop_label = drop_label
      @choose_label = choose_label
      @change_label = change_label
    end

    # Field hands the control its id, name, required and the aria that describes it; the aria goes
    # to the input, which is what the label's `for` names, and everything else stays on the root.
    def extract_control_aria!
      aria = html_attributes[:aria] || {}
      @control_aria = aria.slice(*CONTROL_ARIA)
      remaining = aria.except(*CONTROL_ARIA)
      remaining.empty? ? html_attributes.delete(:aria) : html_attributes[:aria] = remaining
    end

    # Rails' own id derivation, the same one Ui::FieldComponent uses.
    def derive_control_id
      name.delete(']').tr('^-a-zA-Z0-9:.', '_')
    end
  end
end
