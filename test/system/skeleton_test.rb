# frozen_string_literal: true

require 'application_system_test_case'

class SkeletonTest < ApplicationSystemTestCase
  setup do
    visit skeleton_path
    disable_transitions
  end

  test 'the pulse stops under emulated prefers-reduced-motion: reduce' do
    skeleton = preview.all('[data-slot=skeleton]').first
    assert_not_equal 'none', animation_name_of(skeleton), 'skeleton is not pulsing by default'

    emulate_reduced_motion(true)
    assert_equal 'none', animation_name_of(skeleton), 'skeleton keeps pulsing under prefers-reduced-motion: reduce'
  ensure
    emulate_reduced_motion(false)
  end

  test 'the skeleton preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#skeleton-preview')

    use_dark_mode(true)
    assert_accessible(within: '#skeleton-preview')
  end

  private

  def preview
    find_by_id('skeleton-preview')
  end

  def animation_name_of(element)
    page.evaluate_script('getComputedStyle(arguments[0]).animationName', element)
  end

  # CDP media-feature emulation, the way ApplicationSystemTestCase emulates forced
  # colours -- prefers-reduced-motion has no shared helper since Skeleton is the
  # only component that reacts to it.
  def emulate_reduced_motion(active)
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia',
                                    features: [{ name: 'prefers-reduced-motion', value: active ? 'reduce' : 'no-preference' }])
    assert_equal active, page.evaluate_script("matchMedia('(prefers-reduced-motion: reduce)').matches"), 'reduced motion emulation did not apply'
  end
end
