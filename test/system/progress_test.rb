# frozen_string_literal: true

require 'application_system_test_case'

class ProgressTest < ApplicationSystemTestCase
  setup do
    visit progress_path
    disable_transitions
  end

  test 'every progress bar exposes role=progressbar with a non-empty accessible name' do
    preview.all('[data-slot=progress]').each do |bar|
      assert_equal 'progressbar', bar['role']
      assert_not_nil bar['aria-valuenow'], 'progress bar has no aria-valuenow'
      assert_not_empty accessible_name_of(bar), 'progress bar has no accessible name'
    end
  end

  test 'each documented bar announces the value shown in its caption' do
    {
      'Uploading photo.png' => '60',
      'Step 3 of 5' => '3',
      'Waiting to start' => '0',
      'Import complete' => '100'
    }.each do |label, value|
      bar = preview.find("[data-slot=progress][aria-label='#{label}']")
      assert_equal value, bar['aria-valuenow']
    end

    labelledby_bar = preview.find('[data-slot=progress][aria-labelledby="disk-usage-heading"]')
    assert_equal '82', labelledby_bar['aria-valuenow']
    assert_equal 'Disk usage — 82%', accessible_name_of(labelledby_bar)
  end

  # The fill (bg-primary) is the non-text indicator that carries meaning (rule 4);
  # the track (bg-muted) is decoration and is exempt. Checked on the default,
  # unstyled bar -- the docs' own bg-destructive/20 track example recolours
  # decoration on purpose and isn't the pairing this rule is about.
  test 'the fill reaches 3:1 against the track on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      bar = preview.all('[data-slot=progress]').first
      track = color_of(:background, bar)
      fill = color_of(:background, bar.find('div', visible: :all))
      ratio = contrast_ratio(fill, track)
      assert_operator ratio, :>=, 3, "fill is #{ratio.round(2)}:1 against the track on #{surface} in #{mode} mode"
    end
  end

  test 'the progress preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#progress-preview')

    use_dark_mode(true)
    assert_accessible(within: '#progress-preview')
  end

  private

  def preview
    find_by_id('progress-preview')
  end

  # No shared accessible-name helper exists (Spinner and Breadcrumb each read their
  # own name-bearing attribute inline); this covers both name sources Progress accepts.
  def accessible_name_of(element)
    page.evaluate_script(<<~JS, element)
      (() => {
        const el = arguments[0]
        const label = el.getAttribute('aria-label')
        if (label) return label
        const labelledby = el.getAttribute('aria-labelledby')
        if (labelledby) return (document.getElementById(labelledby)?.textContent || '').trim()
        return ''
      })()
    JS
  end
end
