# frozen_string_literal: true

module Stress
  # Opening and dismissing one row of the table. Each opening gesture is the one its owning spec
  # names, and each waits for the overlay to settle, so the next step never races an animation.
  module Moves
    # ui-modal-turbo § Behavior, item 2 (the frame link); ui-select § Behavior, items 16 and 17
    # (select-only opens on a click, the editable combobox on Alt+ArrowDown); a Tooltip on hover
    # (ui-foundation-retrofit); everything else on its trigger.
    def open_overlay(overlay)
      case overlay.key
      when :T then find(overlay.trigger).hover
      when :S2, :SC
        find(overlay.trigger).click
        press_chord(:alt, :arrow_down)
      else find(overlay.trigger).click
      end
      await_state(overlay.content, 'open')
    end

    def dismiss_overlay(overlay, way)
      case way
      when :escape then press(:escape)
      when :outside then overlay.outside == :backdrop ? click_backdrop(overlay.content) : click_region(overlay.outside)
      when :own then own_close(overlay)
      end
      await_state(overlay.content, 'closed')
    end

    private

    # The table's "own close" column (§ Behavior, item 11).
    def own_close(overlay)
      case overlay.key
      when :M then find('#stress-modal-close').click
      when :C then find('#default-confirm [data-ui--dialog-cancel]').click
      when :S1, :S2, :SF, :SC then commit_option
      when :Dm then find("##{overlay.scope}-dm-close").click
      when :T then point_at("##{overlay.scope}-outside")
      else find(overlay.trigger).click
      end
    end

    # ui-select § Behavior, items 16 and 17: ArrowDown makes an option active, Enter selects it and
    # closes, and focus stays on the combobox.
    def commit_option
      press(:arrow_down)
      press(:enter)
    end
  end
end
