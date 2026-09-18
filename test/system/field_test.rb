# frozen_string_literal: true

require 'application_system_test_case'

class FieldTest < ApplicationSystemTestCase
  setup do
    visit field_path
    disable_transitions
  end

  test 'the field preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#field-preview')

    use_dark_mode(true)
    assert_accessible(within: '#field-preview')
  end

  test 'error text reaches 4.5:1 on every token surface in light and dark mode' do
    each_token_surface(preview) do |mode, surface|
      error = preview.find('[data-slot=field-error]')
      ratio = contrast_ratio(color_of(:text, error), color_of(:background, preview))
      assert_operator ratio, :>=, 4.5, "error text is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  test 'the required preview passes an accessibility audit in light and dark mode' do
    assert_accessible(within: '#field-required-preview')

    use_dark_mode(true)
    assert_accessible(within: '#field-required-preview')
  end

  # The marker is aria-hidden, so the name a screen reader speaks is the label text alone, and
  # "required" comes from the control (ui-field-model-binding § Business rules, rule 6).
  test 'a required control is named by its label text alone, with no marker glyph' do
    control = find('#profile_email')
    assert_selector '#profile_email[required]'
    assert_selector "label[for='profile_email'] [data-slot=field-required-indicator]", text: '*'

    assert_equal 'Email', control.native.accessible_name
  end

  # The same claim, read out of Chrome's own accessibility tree rather than an attribute (the
  # route select_accessibility_test.rb's SA10 uses): the hidden required-label span added for
  # search mode's Select trigger sits inside every required Field's <label>, and a `<label for>`
  # control -- Input, here -- must not pick it up too, or "required" is announced twice
  # (ui-select § Behavior, item 17, "Required is the label's to say"). `required` itself still
  # reaches the tree, but as the control's own state, not through its name.
  test 'a required Input\'s computed accessible name is the plain label, with required as its own state' do
    assert_equal 'Email', ax('#profile_email', 'name')
    assert_equal true, ax_property('#profile_email', 'required')
  end

  test 'a field given required: false over its validator renders no marker and no required' do
    assert_selector '#profile_handle:not([required])'
    assert_no_selector "label[for='profile_handle'] [data-slot=field-required-indicator]"
  end

  test 'the required marker reaches 4.5:1 on every token surface in light and dark mode' do
    container = find_by_id('field-required-preview')
    marker = container.find('[data-slot=field-required-indicator]')

    each_token_surface(container) do |mode, surface|
      ratio = contrast_ratio(color_of(:text, marker), color_of(:background, container))
      assert_operator ratio, :>=, 4.5, "the required marker is #{ratio.round(2)}:1 on #{surface} in #{mode} mode"
    end
  end

  private

  def preview
    find_by_id('field-preview')
  end

  # ax_node (Chrome's accessibility tree for one element) comes from ApplicationSystemTestCase's
  # BrowserHelpers.
  def ax(selector, key)
    ax_node(selector)&.dig(key, 'value')
  end

  def ax_property(selector, name)
    ax_node(selector)&.fetch('properties', [])&.find { |property| property['name'] == name }&.dig('value', 'value')
  end
end
