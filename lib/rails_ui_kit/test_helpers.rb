# frozen_string_literal: true

module RailsUiKit
  # Capybara helpers for host application test suites.
  #
  #   require "rails_ui_kit/test_helpers"
  #
  #   class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  #     include RailsUiKit::TestHelpers
  #   end
  #
  #   ui_select "Pending", from: "Status"
  #
  # Enhanced, Ui::SelectComponent lays its native <select> over its own control at `opacity: 0`,
  # so a host's `select "Pending", from: "Status"` no longer picks what the user would. This drives
  # the widget the way a person does -- press the control, then choose the option -- and falls back
  # to the native select where the component was never enhanced, so one call covers every state.
  #
  # Not required by the engine: it loads nothing at runtime, and a host that writes no system
  # test never loads it.
  module TestHelpers
    class OptionNotFound < Capybara::ElementNotFound; end

    SELECT_ROOT = "[data-slot='select']"
    # The element that owns the listbox, in either mode: the combobox in select-only mode, the
    # trigger button in search mode. Search mode's own role="combobox" is the field inside the
    # popup, which takes a query rather than the value, so it is never what this drives.
    CONTROL = "[data-ui--overlay-target='trigger']"
    # The button beside the control that returns it to the prompt, where the Select has one.
    CLEAR = "[data-ui--select-target='clear']"
    # A label's accessible text, read in the browser (see ui_select_label_name).
    LABEL_NAME = <<~JS
      ((label) => {
        const clone = label.cloneNode(true)
        clone.querySelectorAll('[aria-hidden="true"], [hidden]').forEach((node) => node.remove())
        return clone.textContent.replace(/\\s+/g, ' ').trim()
      })(arguments[0])
    JS

    # Chooses `text` in the Select named by `from:` -- its Field label, its own aria-label, or the
    # id or name of the select inside it.
    def ui_select(text, from:)
      root = ui_select_root(from)
      control = root.first(CONTROL, minimum: 0, wait: 0)
      return ui_select_natively(root, text, from) unless control&.visible?

      cleared = ui_select_clear(root, text)
      if cleared
        cleared.click
        return control
      end

      ui_select_open(control, from)
      ui_select_option(root, control, text, from).click
      ui_select_expanded?(control, 'false') ||
        raise(OptionNotFound, "the Select for #{from.inspect} stayed open after choosing #{text.inspect}")
      control
    end

    private

    # Exactly one Select may answer to a name: two that do is the same mistake Capybara's own
    # Ambiguous error exists to catch, and silently taking the first would write the value into a
    # control the test never meant.
    def ui_select_root(from)
      roots = all(SELECT_ROOT, visible: :all, wait: 0).select { |root| ui_select_named?(root, from) }
      return roots.first if roots.one?

      raise Capybara::Ambiguous, "found #{roots.size} Selects for #{from.inspect}" if roots.size > 1

      raise OptionNotFound, "found no Ui::SelectComponent for #{from.inspect}"
    end

    # A Select answers to the Field label that names it, to its own aria-label, and to the id or
    # name of the select inside it -- whichever the host's test already says.
    def ui_select_named?(root, from)
      native = ui_select_native(root)
      return false unless native
      return true if [native[:id], native[:name]].include?(from.to_s)

      ui_select_names(root, native).any? { |name| name.strip == from.to_s.strip }
    end

    def ui_select_names(root, native)
      label = page.first("label[for='#{native[:id]}']", visible: :all, minimum: 0, wait: 0)
      control = root.first(CONTROL, visible: :all, minimum: 0, wait: 0)

      [(ui_select_label_name(label) if label), native[:'aria-label'], control&.[](:'aria-label')].compact
    end

    # The label's accessible text: what a screen reader reads out, and what a host means by
    # `from:`. Read in the browser from a clone with every aria-hidden and hidden descendant
    # removed, so a Field's required marker and its hidden "required" never join the name; and
    # read whether or not the label is painted, because a label scrolled behind an open Modal is
    # one the driver reports as not displayed, and dropping it made the ambiguity check
    # under-count -- the helper then picked the other Select instead of raising.
    def ui_select_label_name(label)
      page.evaluate_script(LABEL_NAME, label)
    end

    def ui_select_native(root)
      root.first('select', visible: :all, minimum: 0, wait: 0)
    end

    # A prompt is a placeholder rather than a choice, so the listbox does not list it: the way back
    # to it is the clear button, which is what a person presses (ui-select § Behavior, item 10).
    # Asking for the prompt by name means that button, where the component rendered one -- Rails
    # renders the prompt first, and only while nothing is chosen, so it is the leading option.
    def ui_select_clear(root, text)
      prompt = ui_select_native(root)&.first('option', visible: :all, minimum: 0, wait: 0)
      return unless prompt && prompt[:value].to_s.empty? && prompt.text(:all).strip == text.to_s.strip

      button = root.first(CLEAR, minimum: 0, wait: 0)
      button if button&.visible?
    end

    # Both modes open on a press of the control, which is what a person does.
    def ui_select_open(control, from)
      return if control[:'aria-expanded'] == 'true'

      control.click
      return if ui_select_expanded?(control, 'true')

      raise OptionNotFound, "the Select for #{from.inspect} did not open"
    end

    # Named after what the caller asked for, not after an internal id: a host debugging its own
    # suite should be told which Select and what it offers, not handed a selector.
    def ui_select_option(root, control, text, from)
      listbox = find("##{control[:'aria-controls']}", visible: :all)
      option = listbox.all('[role=option]').find { |candidate| candidate.text.strip == text.to_s.strip }
      return option if option

      offered = ui_select_option_texts(root)
      raise OptionNotFound,
            "the Select for #{from.inspect} has no option #{text.inspect}. It offers: #{offered.inspect}"
    end

    # Not enhanced -- JavaScript never ran, or select-only mode kept the platform picker on a
    # touch screen. The native select is the control, and it is chosen the way any select is.
    def ui_select_natively(root, text, from)
      native = ui_select_native(root)
      option = native.all('option', text: text, exact_text: true, visible: :all, minimum: 0).first
      unless option
        raise OptionNotFound,
              "the Select for #{from.inspect} has no option #{text.inspect}. " \
              "It offers: #{ui_select_option_texts(root).inspect}"
      end

      option.select_option
      native
    end

    def ui_select_option_texts(root)
      ui_select_native(root).all('option', visible: :all).map { |option| option.text.strip }
    end

    # Capybara's own waiting matcher rather than a polled loop under Timeout: interrupting a
    # request that is already in flight to the browser can leave the session wedged.
    def ui_select_expanded?(control, expanded)
      control.matches_css?("[aria-expanded='#{expanded}']", wait: Capybara.default_max_wait_time)
    end
  end
end
