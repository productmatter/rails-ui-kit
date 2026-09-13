# frozen_string_literal: true

require 'application_system_test_case'

class AlertTest < ApplicationSystemTestCase
  # Title text of the Preview section's two full alerts (icon + title + description),
  # keyed by variant -- distinct from the compact Variants list below it, which only
  # sets a title and would otherwise collide on exact_text: "Default"/"Destructive".
  VARIANTS = { 'default' => 'Update available', 'destructive' => 'Payment failed' }.freeze

  setup do
    visit alert_path
    disable_transitions
  end

  test 'every variant title and description reaches 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      VARIANTS.each do |variant, title_text|
        alert = variant_alert(title_text)
        title = alert.find('[data-slot=alert-title]')
        description = alert.find('[data-slot=alert-description]')

        title_ratio = contrast_ratio(color_of(:text, title), color_of(:background, alert))
        assert_operator title_ratio, :>=, 4.5, "#{variant} title is #{title_ratio.round(2)}:1 on #{surface} in #{mode} mode"

        description_ratio = contrast_ratio(color_of(:text, description), color_of(:background, alert))
        assert_operator description_ratio, :>=, 4.5, "#{variant} description is #{description_ratio.round(2)}:1 on #{surface} in #{mode} mode"
      end
    end
  end

  test 'the border reaches 3:1 against the surface in light and dark mode for every variant' do
    each_token_surface(preview) do |mode, surface|
      VARIANTS.each do |variant, title_text|
        alert = variant_alert(title_text)
        border = color_of(:border, alert)
        ratio = contrast_ratio(border, color_of(:background, preview))
        assert_operator ratio, :>=, 3, "#{variant} border is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
      end
    end
  end

  test 'the icon is hidden from assistive tech in the preview' do
    icon = variant_alert('Update available').find('[data-slot=alert-icon]', visible: :all)
    assert_equal 'true', icon['aria-hidden']
  end

  test 'the alert preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#alert-preview')

    use_dark_mode(true)
    assert_accessible(within: '#alert-preview')
  end

  private

  def preview
    find_by_id('alert-preview')
  end

  def variant_alert(title_text)
    preview.find('[data-slot=alert-title]', exact_text: title_text).find(:xpath, 'ancestor::*[@data-slot="alert"][1]')
  end
end
