# frozen_string_literal: true

require 'test_helper'

module Ui
  # The character counter rides Field's existing description-and-error swap and adds no
  # mechanism of its own (ui-character-counter § Behavior, items 4-5 and 9-11; § Business
  # rules, rules 1 and 3).
  class FieldCharacterCounterTest < ViewComponent::TestCase
    class Note
      include ActiveModel::API

      attr_accessor :body
    end

    def render_field(body:, limit: 20, description: true, errors: nil, **overrides)
      note = Note.new(body: body)
      render_inline(Ui::FieldComponent.new(model: note, attribute: :body, errors: errors, **overrides)) do |field|
        field.with_control(Ui::TextareaComponent, counter: true, limit: limit)
        field.with_description { 'Keep it brief.' } if description
      end
    end

    def description
      page.find('[data-slot=field-description]', visible: :all)
    end

    def count_span
      description.find('[data-ui--character-count-target=count]', visible: :all)
    end

    test 'the count is the last child of the description part, on the same line as the help text' do
      render_field(body: 'hello')

      assert_selector "[data-slot='field-description'] > *:last-child[data-ui--character-count-target='count']",
                      text: '5 / 20', visible: :all
      assert_includes description.text, 'Keep it brief.'
    end

    test 'a counter with no description renders the description part holding the count alone' do
      render_field(body: 'ok', description: false)

      assert_selector "[data-slot='field-description']", visible: :all
      assert_equal '2 / 20', count_span.text
    end

    test 'aria-describedby names the description even without with_description' do
      render_field(body: 'ok', description: false)

      described_by = page.find('textarea')['aria-describedby']
      description_id = description['id']
      assert_includes described_by, description_id
    end

    # A line break counts as one code point, matching Ruby's String#length -- corrected from
    # the spec's "counted as two" (CRLF), which a posted line break through the docs demo
    # showed Rails does not actually receive as two in this stack. Agreeing with the server
    # is the rule that matters (ui-character-counter § Business rules, rule 2); see the
    # comment on Ui::FieldComponent#character_count.
    test 'counts code points, a line break included as one' do
      render_field(body: "a\nb", limit: 20)

      assert_equal '3 / 20', count_span.text
    end

    test 'counts an emoji sequence by code points, matching Ruby String#length' do
      render_field(body: '😀😀', limit: 20)

      assert_equal 2, '😀😀'.length
      assert_equal '2 / 20', count_span.text
    end

    test 'past the limit the count is destructive with data-over, and nothing else changes' do
      render_field(body: 'x' * 25, limit: 20)

      span = count_span
      assert_equal 'true', span['data-over']
      assert_includes span['class'].split, 'text-destructive'
      assert_nil page.find('textarea')['aria-invalid']
      assert_no_selector '[data-slot=field-error]'
      assert_no_selector "[data-slot='field'][data-invalid]"
    end

    test 'an invalid field hides the description behind the error, keeping the count tracked' do
      render_field(body: 'hello', errors: ['is required'])

      assert_selector "[data-slot='field-description'][hidden]", visible: :all
      assert_equal '5 / 20', count_span.text
      assert_selector '[data-slot=field-error]', text: 'is required'
    end

    test 'counter: without limit: through with_control raises' do
      assert_raises(ArgumentError) do
        render_inline(Ui::FieldComponent.new(name: 'note[body]')) do |field|
          field.with_control(Ui::TextareaComponent, counter: true)
        end
      end
    end

    test 'the wrapper joins ui--character-count onto ui--field only when a counter is present' do
      render_field(body: 'hi', limit: 20)

      assert_equal 'ui--field ui--character-count', page.find('[data-slot=field]')['data-controller']
    end

    test 'without a counter the wrapper carries only ui--field' do
      render_inline(Ui::FieldComponent.new(name: 'user[email]')) do |field|
        field.with_label { 'Email' }
        field.with_control(Ui::InputComponent)
      end

      assert_equal 'ui--field', page.find('[data-slot=field]')['data-controller']
    end

    test 'the wrapper carries the limit, format, plural maps and locale ui--character-count reads' do
      render_field(body: 'hi', limit: 20)

      wrapper = page.find('[data-slot=field]')
      assert_equal '20', wrapper['data-ui--character-count-limit-value']
      assert_equal I18n.t('rails_ui_kit.character_counter.count'), wrapper['data-ui--character-count-format-value']
      assert_equal 'en', wrapper['data-ui--character-count-locale-value']
      remaining = JSON.parse(wrapper['data-ui--character-count-remaining-value'])
      assert_equal I18n.t('rails_ui_kit.character_counter.remaining')[:one], remaining['one']
    end

    test 'in fr, the wrapper carries the French locale and plural maps' do
      I18n.with_locale(:fr) do
        render_field(body: 'hi', limit: 20)

        wrapper = page.find('[data-slot=field]')
        assert_equal 'fr', wrapper['data-ui--character-count-locale-value']
        over = JSON.parse(wrapper['data-ui--character-count-over-value'])
        assert_equal I18n.t('rails_ui_kit.character_counter.over', locale: :fr)[:other], over['other']
      end
    end

    test 'a call-site count: format wins over the locale file' do
      template = "#{I18n.t('rails_ui_kit.character_counter.count')} total"
      render_field(body: 'hi', limit: 20, count: template)

      assert_equal format(template, count: 2, limit: 20), count_span.text
    end
  end
end
