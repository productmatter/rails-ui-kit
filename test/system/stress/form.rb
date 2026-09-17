# frozen_string_literal: true

module Stress
  # The form half of the page: the controls' controllers have to survive a 422 re-render, a full
  # reload and a morph (docs/specs/ui-stress-page § Behavior, items 3 and 13).
  module Form
    FORM = '#stress-form'
    SAVE = "#{FORM} button[type=submit]".freeze

    # An invalid submit, the 422, then the enum Select opened and dismissed by Escape.
    def form_invalid_sequence(profile)
      visit_stress(profile)
      record_response_statuses if turbo_on?(profile)
      submit_form(profile, name: '   ')
      assert_unprocessable(profile)

      plan = Overlay.build(:SF)
      open_overlay(plan)
      dismiss_overlay(plan, :escape)
      # ui-select § Behavior, item 16: Escape closes with no change, focus never leaves the combobox.
      check(profile, 'form invalid, then S1 by Escape', focus: plan.trigger)
    end

    # A valid submit, then its toast reached by F8 and closed by Escape.
    def form_valid_sequence(profile)
      visit_stress(profile)
      submit_form(profile, name: 'Ada')
      await_toast_settled
      reach_toast_and_close

      # ui-toast § Behavior, item 12: Escape returns focus to where F8 recorded it came from. With
      # Turbo on that's the Save button, which ui--turbo-disable-with gives focus back when the
      # submission ends (open-questions.md, decided (b)); with Turbo off it's <body>, after the
      # full page load the redirect is.
      check(profile, 'form valid', focus: turbo_on?(profile) ? SAVE : :body)
    end

    def turbo_on?(profile)
      profile[:turbo] == :on
    end

    ANSWERED = <<~JS.freeze
      document.querySelector('#{FORM}')?.dataset.stressRender !== arguments[0] ||
        !!document.querySelector('#{Flows::TOAST}')
    JS

    RE_RENDERED = "document.querySelector('#{FORM}')?.dataset.stressRender !== arguments[0]".freeze

    private

    # A 422 re-renders the form (morphed, on this page), a Turbo-off success re-renders the page
    # with a toast, and a Turbo success renders nothing but a toast: each is waited on by what only
    # it produces, and a render is a new arrival.
    def submit_form(profile, name:)
      fill_in 'Name', with: name
      find("#{FORM} label", text: 'Email', match: :first).click
      assert_selector "#{FORM} input[type=checkbox][value=email]:checked"
      previous = token_of(FORM)

      find(SAVE).click
      await_js(ANSWERED, previous, message: 'the submission never answered')
      arrive(profile) if page.evaluate_script(RE_RENDERED, previous)
    end

    def assert_unprocessable(profile)
      assert_equal 422, turbo_on?(profile) ? response_statuses.last : navigation_status
      assert_selector "#{FORM} #stress_record_name[aria-invalid=true]"
    end

    # A Turbo-off submit is a full document load, so its status is the navigation's own.
    def navigation_status
      page.evaluate_script("performance.getEntriesByType('navigation')[0].responseStatus")
    end
  end
end
