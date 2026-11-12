# frozen_string_literal: true

require 'test_helper'

module Ui
  # Choices' two compact appearances, `variant: :segmented` and `variant: :chips`: the same inputs,
  # names, ids and hidden field as list and card, with the input visually hidden and the label as
  # the control. The list and card markup are pinned by ChoicesComponentTest; nothing here may
  # change them.
  class ChoicesCompactVariantsTest < ViewComponent::TestCase
    ZOOMS = [%w[Fit fit], %w[150% 150], %w[200% 200]].freeze
    State = Struct.new(:id, :name, :total)
    STATES = [State.new('unmapped', 'Unmapped', 250), State.new('suggested', 'Suggested', 36),
              State.new('salt', 'SALT', 0)].freeze

    def render_chips(**)
      render_inline(Ui::ChoicesComponent.new(name: 'filter[state]', variant: :chips, collection: STATES,
                                             value_method: :id, text_method: :name, **))
    end

    test 'segmented is a radiogroup of real radios, visually hidden, with no indicator' do
      render_inline(Ui::ChoicesComponent.new(name: 'view[zoom]', variant: :segmented, options: ZOOMS, checked: 'fit',
                                             aria: { label: 'Zoom' }))

      assert_selector "fieldset[role='radiogroup'][aria-label='Zoom']"
      radios = page.all("input[type='radio'][name='view[zoom]']", visible: :all)
      assert_equal %w[fit 150 200], radios.map(&:value)
      assert radios.first.checked?
      radios.each { |radio| assert_includes radio[:class].split, 'sr-only' }
      assert_no_selector 'svg', visible: :all
    end

    test 'segmented reads the control height token at each step, so it is one control tall' do
      { xs: 'h-(--control-height-xs)', default: 'h-(--control-height)', '2xl': 'h-(--control-height-2xl)' }.each do |step, height|
        render_inline(Ui::ChoicesComponent.new(name: 'view[zoom]', variant: :segmented, options: ZOOMS, size: step))

        classes = page.find('fieldset')[:class].split
        assert_includes classes, height, "segmented at #{step}"
        assert_includes classes, 'inline-flex'
        refute_includes classes, 'grid', 'the compact root replaces the stacking grid'
      end
    end

    test 'a caller class still wins over the compact root' do
      render_chips(class: 'grid grid-cols-3')

      classes = page.find('fieldset')[:class].split
      assert_includes classes, 'grid'
      assert_includes classes, 'grid-cols-3'
      refute_includes classes, 'flex'
    end

    test 'segmented refuses multiple: true and description_method:' do
      error = assert_raises(ArgumentError) do
        render_inline(Ui::ChoicesComponent.new(name: 'z', variant: :segmented, options: ZOOMS, multiple: true))
      end
      assert_includes error.message, 'variant: :chips'

      assert_raises(ArgumentError) do
        render_inline(Ui::ChoicesComponent.new(name: 'z', variant: :segmented, collection: STATES, value_method: :id,
                                               text_method: :name, description_method: :name))
      end
    end

    test 'a chip carries its mark and its count, and the count joins its accessible name' do
      mark = ->(state) { ActionController::Base.helpers.tag.span(class: "mark-#{state.id}") }
      render_chips(icon_method: mark, count_method: :total, checked: 'suggested')

      radio = page.find("input[value='suggested']", visible: :all)
      assert radio.checked?
      assert_equal 'filter_state_suggested-label filter_state_suggested-count', radio['aria-labelledby']
      assert_equal '36', page.find('#filter_state_suggested-count').text
      assert_selector "[aria-hidden='true'] .mark-suggested", visible: :all
    end

    test 'a zero count is still a count' do
      render_chips(count_method: :total)

      assert_equal '0', page.find('#filter_state_salt-count').text
      assert_equal 'filter_state_salt-label filter_state_salt-count',
                   page.find("input[value='salt']", visible: :all)['aria-labelledby']
    end

    test 'chips without a count are named by their text alone' do
      render_chips

      assert_equal 'filter_state_unmapped-label', page.find("input[value='unmapped']", visible: :all)['aria-labelledby']
      assert_no_selector '[id$=-count]'
    end

    test 'multiple chips are checkboxes posting name[] with the hidden empty field' do
      render_chips(multiple: true, checked: %w[unmapped salt])

      assert_selector "input[type='hidden'][name='filter[state][]'][value='']", visible: :all
      boxes = page.all("input[type='checkbox'][name='filter[state][]']", visible: :all)
      assert_equal [true, false, true], boxes.map(&:checked?)
      assert_no_selector "fieldset[role='radiogroup']"
    end

    test 'chips read the control scale at each step' do
      render_chips(size: :sm)

      assert_includes page.first('label')[:class].split, 'h-(--control-height-sm)'
    end

    test 'count_method: is refused outside chips, and needs a collection' do
      assert_raises(ArgumentError) do
        render_inline(Ui::ChoicesComponent.new(name: 's', collection: STATES, value_method: :id, text_method: :name,
                                               count_method: :total))
      end

      error = assert_raises(ArgumentError) do
        render_inline(Ui::ChoicesComponent.new(name: 's', variant: :chips, options: ZOOMS, count_method: :total))
      end
      assert_includes error.message, 'count_method:'
    end

    test 'list and card ignore the compact classes entirely' do
      render_inline(Ui::ChoicesComponent.new(name: 'p', options: ZOOMS, size: :xs))

      classes = page.find('fieldset')[:class].split
      assert_includes classes, 'grid'
      refute(classes.any? { |name| name.include?('control-height') })
      assert_selector 'svg', visible: :all, count: 3
    end
  end
end
