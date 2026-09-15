# frozen_string_literal: true

require_relative '../../support/pseudo_locale'

module Stress
  # The six conditions (docs/specs/ui-stress-page § Behavior, item 5). Each is applied by the test
  # and proved in force before a sequence runs and again when the invariants run; teardown undoes
  # every one, because CDP emulation outlives a test in a shared browser.
  module Conditions
    # Read from the page, never assumed: the locale from a kit chrome string the layout renders,
    # Turbo from the form's own attribute.
    PROOF = <<~JS
      ((marker) => ({
        theme: document.documentElement.classList.contains('dark') ? 'dark' : 'light',
        motion: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'reduced' : 'full',
        viewport: innerWidth,
        direction: document.documentElement.dir === 'rtl' && getComputedStyle(document.body).direction === 'rtl' ? 'rtl' : 'ltr',
        locale: (document.querySelector('[data-default-title]')?.dataset.defaultTitle || '').includes(marker) ? 'pseudo' : 'en',
        turbo: document.querySelector('#stress-form')?.dataset.turbo === 'false' ? 'off' : 'on'
      }))(...arguments)
    JS

    # Emulated through CDP before the visit, the way the harness emulates forced colours. The
    # viewport is device metrics rather than a window resize: Chrome clamps its own window at
    # 500 px wide on this platform, so a resize to 320 silently leaves a 500 px page
    # (§ Assumptions, and docs/specs/ui-stress-page/status.md).
    def apply_emulation(profile)
      cdp('Emulation.setEmulatedMedia', features: motion_features(profile))
      return resize_viewport_to(*ApplicationSystemTestCase::SCREEN_SIZE) unless profile[:viewport] == 320

      cdp('Emulation.setDeviceMetricsOverride', width: 320, height: 800, deviceScaleFactor: 1, mobile: false)
    end

    def reset_emulation
      cdp('Emulation.setEmulatedMedia', features: [])
      cdp('Emulation.clearDeviceMetricsOverride')
      resize_viewport_to(*ApplicationSystemTestCase::SCREEN_SIZE)
    end

    # Applied to a rendered page: the theme through the documented toggle, the direction on <html>
    # (the examples app's own `dir` switch is part of the RTL deferral, § Behavior, item 7).
    def apply_page_conditions(profile)
      apply_direction(profile)
      return unless profile[:theme] == :dark && page.evaluate_script("!document.documentElement.classList.contains('dark')")

      find('#stress-theme-toggle').click
      await_js("document.documentElement.classList.contains('dark')", message: 'the theme toggle never applied dark mode')
    end

    # Re-applied after every document render: a full page load starts from the server's markup.
    def apply_direction(profile)
      return unless profile[:direction] == :rtl

      page.execute_script("document.documentElement.dir = 'rtl'")
    end

    def assert_conditions(profile, context)
      wanted = profile.slice(:theme, :motion, :direction, :locale, :turbo).merge(viewport: profile[:viewport])
      in_force = page.evaluate_script(PROOF, PseudoLocale::OPEN).symbolize_keys.transform_values { |value| value.is_a?(String) ? value.to_sym : value }
      wanted.each do |condition, value|
        assert_equal value, in_force[condition], "#{context}: the #{condition} condition is not in force"
      end
    end

    def stress_query(profile)
      { locale: (PseudoLocale::LOCALE if profile[:locale] == :pseudo), turbo: ('off' if profile[:turbo] == :off) }.compact
    end

    private

    def motion_features(profile)
      profile[:motion] == :reduced ? [{ name: 'prefers-reduced-motion', value: 'reduce' }] : []
    end

    def cdp(command, **arguments)
      cdp_browser&.execute_cdp(command, **arguments)
    end
  end
end
