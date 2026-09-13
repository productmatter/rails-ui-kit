# frozen_string_literal: true

require 'test_helper'

module Ui
  class ProgressComponentTest < ViewComponent::TestCase
    def progress
      page.find('[data-slot=progress]')
    end

    def fill
      progress.find('div', visible: :all)
    end

    test 'renders a div with role=progressbar' do
      render_inline(Ui::ProgressComponent.new(value: 50, label: 'Uploading'))

      assert_selector "div[data-slot='progress'][role='progressbar']"
    end

    test 'stamps data-slot on the root element' do
      render_inline(Ui::ProgressComponent.new(value: 50, label: 'Uploading'))

      assert_selector "[data-slot='progress']"
    end

    test 'reflects value and max on aria-valuenow/aria-valuemin/aria-valuemax' do
      render_inline(Ui::ProgressComponent.new(value: 30, max: 80, label: 'Uploading'))

      assert_selector "[data-slot='progress'][aria-valuenow='30'][aria-valuemin='0'][aria-valuemax='80']"
    end

    test 'defaults max to 100' do
      render_inline(Ui::ProgressComponent.new(value: 30, label: 'Uploading'))

      assert_selector "[data-slot='progress'][aria-valuemax='100']"
    end

    test 'a missing value renders as 0, never indeterminate' do
      render_inline(Ui::ProgressComponent.new(label: 'Uploading'))

      assert_selector "[data-slot='progress'][aria-valuenow='0']"
      assert_equal '0%', fill['style'].delete(' ').sub('width:', '')
    end

    test 'value 0 renders an empty fill' do
      render_inline(Ui::ProgressComponent.new(value: 0, label: 'Uploading'))

      assert_selector "[data-slot='progress'][aria-valuenow='0']"
      assert_equal '0%', fill['style'].delete(' ').sub('width:', '')
    end

    test 'value equal to max renders a full fill' do
      render_inline(Ui::ProgressComponent.new(value: 100, label: 'Uploading'))

      assert_selector "[data-slot='progress'][aria-valuenow='100']"
      assert_equal '100%', fill['style'].delete(' ').sub('width:', '')
    end

    test 'an out-of-range value clamps to max' do
      render_inline(Ui::ProgressComponent.new(value: 140, max: 100, label: 'Uploading'))

      assert_selector "[data-slot='progress'][aria-valuenow='100']"
      assert_equal '100%', fill['style'].delete(' ').sub('width:', '')
    end

    test 'a negative value clamps to 0' do
      render_inline(Ui::ProgressComponent.new(value: -20, label: 'Uploading'))

      assert_selector "[data-slot='progress'][aria-valuenow='0']"
    end

    test 'a fractional value is preserved and reflected in the fill width' do
      render_inline(Ui::ProgressComponent.new(value: 33.3, label: 'Uploading'))

      assert_selector "[data-slot='progress'][aria-valuenow='33.3']"
      assert_equal '33.3%', fill['style'].delete(' ').sub('width:', '')
    end

    test 'label: sets the accessible name via aria-label' do
      render_inline(Ui::ProgressComponent.new(value: 50, label: 'Uploading files'))

      assert_selector "[data-slot='progress'][aria-label='Uploading files']"
    end

    test 'a missing label raises in development and test' do
      assert_raises(ArgumentError) { render_inline(Ui::ProgressComponent.new(value: 50)) }
    end

    test 'a forwarded aria-labelledby satisfies the accessible-name requirement' do
      render_inline(Ui::ProgressComponent.new(value: 50, aria: { labelledby: 'upload-heading' }))

      assert_selector "[data-slot='progress'][aria-labelledby='upload-heading']"
      assert_nil progress['aria-label']
    end

    test 'a forwarded aria-label satisfies the accessible-name requirement' do
      render_inline(Ui::ProgressComponent.new(value: 50, aria: { label: 'Upload progress' }))

      assert_selector "[data-slot='progress'][aria-label='Upload progress']"
    end

    test 'caller class wins over a conflicting default' do
      render_inline(Ui::ProgressComponent.new(value: 50, label: 'Uploading', class: 'bg-secondary'))

      assert_includes progress['class'].split, 'bg-secondary'
      assert_not_includes progress['class'].split, 'bg-muted'
    end

    test 'forwards arbitrary html attributes to the root element' do
      render_inline(Ui::ProgressComponent.new(value: 50, label: 'Uploading', id: 'upload-progress', data: { testid: 'progress' }))

      assert_selector "[data-slot='progress']#upload-progress[data-testid='progress']"
    end
  end
end
