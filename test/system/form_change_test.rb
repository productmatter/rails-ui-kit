# frozen_string_literal: true

require 'application_system_test_case'

# form:changed / form:pristine collide with anything a host names form:* itself, so
# ui--form-change:changed / ui--form-change:pristine ship alongside them, namespaced the way
# every other kit event is. Both pairs have to keep firing together: the old pair is deprecated,
# not removed, until 0.4.0.
class FormChangeTest < ApplicationSystemTestCase
  setup do
    visit form_change_path
  end

  def watch_events
    page.execute_script(<<~JS)
      const form = document.getElementById('fc-demo-form')
      window.__events = []
      const log = (name) => () => window.__events.push(name)
      form.addEventListener('form:changed', log('form:changed'))
      form.addEventListener('form:pristine', log('form:pristine'))
      form.addEventListener('ui--form-change:changed', log('ui--form-change:changed'))
      form.addEventListener('ui--form-change:pristine', log('ui--form-change:pristine'))
    JS
  end

  def events
    page.evaluate_script('window.__events')
  end

  test 'FC1 both the namespaced and the deprecated pair fire on change and on reset' do
    watch_events

    fill_in 'title', with: 'Draft title'
    assert_equal %w[form:changed ui--form-change:changed], events

    page.execute_script('window.__events = []')
    page.execute_script("document.getElementById('fc-demo-form').reset()")
    assert_equal %w[form:pristine ui--form-change:pristine], events
  end
end
