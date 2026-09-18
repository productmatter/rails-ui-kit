# frozen_string_literal: true

module Stress
  # What each flow in Stress::Flows is made of: which overlays it opens, what it waits on, and what
  # the owning spec says the outcome is.
  module FlowSteps
    DISPLACEMENT_PAIRS = { po_then_dm: %i[Po Dm], dm_then_po: %i[Dm Po], dm_then_t: %i[Dm T] }.freeze
    def displacement_pair(kind)
      DISPLACEMENT_PAIRS.fetch(kind).map { |key| Overlay.build(key) }
    end

    TOAST_SETTLED = <<~JS.freeze
      (() => {
        const toast = document.querySelector('#{Flows::TOAST}')
        return !!toast && toast.dataset.state === 'open' &&
          !toast.getAnimations().some((animation) => !['finished', 'idle'].includes(animation.playState))
      })()
    JS

    def fire_modal_toast
      find('#stress-modal-toast').click
      await_toast_settled
    end

    def await_toast_settled
      await_js(TOAST_SETTLED, message: 'the toast never settled open')
    end

    # F8 reaches the newest toast's first action, Escape closes it (ui-toast § Behavior, item 12).
    def reach_toast_and_close
      press(:f8)
      await_js("document.querySelector('#{Flows::TOAST}').contains(document.activeElement)",
               message: 'F8 never reached the toast')
      press(:escape)
      await_js("!document.querySelector('#{Flows::TOAST}')", message: 'Escape never closed the toast')
    end

    def render_stream(name)
      page.execute_script(<<~JS, stress_stream_path(name))
        fetch(arguments[0], { headers: { Accept: 'text/vnd.turbo-stream.html' } })
          .then((response) => response.text())
          .then((html) => Turbo.renderStreamMessage(html))
      JS
    end

    # Opens what the replacement lands under, and returns the overlays left open.
    def stream_setup(kind)
      case kind
      when :status_field then open_all(Overlay.build(:Dd), Overlay.build(:S1))
      when :cluster_over_dm then open_all(Overlay.build(:Dm))
      when :cluster_over_po then open_all(Overlay.build(:Po))
      when :modal then open_all(Overlay.build(:M))
      when :city_field then open_all(Overlay.build(:M), Overlay.build(:S2, 'modal'))
      end
    end

    # "Focus restored as if it had closed" lands on the element that now holds the trigger's id
    # (ui-presence-and-overlay-stack § Behavior, item 18; ui-modal-turbo § Business rules, rule 8).
    def stream_expectation(kind, open)
      modal = open.first
      case kind
      when :status_field then { open: [open.first.content], focus: '#page_status-combobox' }
      when :cluster_over_dm then { focus: '#page-dm-trigger' }
      when :cluster_over_po then { focus: '#page-po-trigger' }
      when :modal then { open: [modal.content], topmost: modal.content }
      when :city_field then { open: [modal.content], focus: '#modal_city-trigger', topmost: modal.content }
      end
    end

    def morph_setup(kind)
      case kind
      when :modal then open_all(Overlay.build(:M))
      when :form_select then open_all(Overlay.build(:SF))
      when :dropdown_select then open_all(Overlay.build(:Dd), Overlay.build(:S1))
      end
    end

    def morph_focus(kind)
      { modal: nil, form_select: '#stress_record_plan-combobox', dropdown_select: '#page_status-combobox' }.fetch(kind)
    end

    def morph_topmost(kind)
      kind == :modal ? '#stress-modal dialog' : nil
    end

    def leave_from(kind)
      case kind
      when :modal
        open_overlay(Overlay.build(:M))
        find('#stress-modal-out').click
      when :dropdown
        open_overlay(Overlay.build(:Dd))
        find('#page-dd-out').click
      when :select then leave_with_filtered_select
      end
    end

    # A Drive visit started from a script: a click anywhere would be an outside click first, and the
    # sequence would no longer be the one it names.
    def leave_with_filtered_select
      select = Overlay.build(:SC)
      filter_select(select, 'lis')
      commit_option
      await_state(select.content, 'closed')

      filter_select(select, 'to')
      page.execute_script('Turbo.visit(arguments[0])', stress_bare_path)
    end

    # Pressing the trigger opens the popup onto its search field, and typing there filters the list
    # (ui-select § Behavior, items 17 and 21). The blank option is first in the unfiltered list, so
    # the filter is what makes "Lisbon" the one ArrowDown reaches.
    def filter_select(select, text)
      open_overlay(select)
      find(select.search_field).set(text)
      await_state(select.content, 'open')
    end

    # ui-select § Behavior, item 32: the value is kept, and the filter and its query cleared.
    def assert_select_restored
      assert_equal 'lisbon', page.evaluate_script("document.querySelector('#stress_record_city').value")
      assert_equal 'Lisbon', page.evaluate_script("document.querySelector('#stress_record_city-trigger').textContent.trim()")
      assert_equal '', page.evaluate_script("document.querySelector('#stress_record_city-search').value"),
                   'the restored Select kept what the user had typed'
      assert page.evaluate_script("![...document.querySelectorAll('#stress_record_city-popup [role=option]')].some((option) => option.hidden)"),
             'the restored Select kept its filter'
    end

    # Opened outermost first, and returned in that order: a sequence names the container first.
    def open_all(*overlays)
      overlays.each { |overlay| open_overlay(overlay) }
      overlays
    end
  end
end
