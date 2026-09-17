# frozen_string_literal: true

require 'test_helper'

# turbo_stream.ui_toast: Turbo's own append, into the stack Ui::ToastContainerComponent renders.
# The browser half -- the toast actually arriving -- is driven in test/system/toast_entry_points_test.rb.
class TurboStreamUiToastTest < ActionView::TestCase
  def builder
    Turbo::Streams::TagBuilder.new(view)
  end

  test 'appends a rendered Ui::ToastComponent to #ui-toasts' do
    stream = Nokogiri::HTML5.fragment(builder.ui_toast(type: :success, description: 'Record saved.'))
    turbo_stream = stream.at_css('turbo-stream')

    assert_equal 'append', turbo_stream['action']
    assert_equal Ui::ToastContainerComponent::STACK_ID, turbo_stream['target']
    toast = turbo_stream.at_css('template').inner_html
    assert_includes toast, 'data-slot="toast"'
    assert_includes toast, 'Record saved.'
  end

  test 'takes a payload Hash with string keys, as a flash or params would give it' do
    html = builder.ui_toast('type' => 'error', 'title' => 'Failed')

    assert_includes html, 'data-ui--toast-type-value="error"'
    assert_includes html, 'Failed'
  end

  test 'validates in Ruby, like a render' do
    assert_raises(Ui::Toast::InvalidPayloadError) do
      builder.ui_toast(description: 'x', actions: [{ label: 'Evil', href: 'javascript:alert(1)' }])
    end
  end
end
