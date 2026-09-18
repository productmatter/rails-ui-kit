# frozen_string_literal: true

require 'test_helper'

module Ui
  # The chrome chain: call site → host locale file → kit default (ui-localization § Behavior,
  # item 2). Chrome is what the kit says in its own voice; content is what the call site
  # writes, and the kit never translates that. Every component that renders chrome takes a
  # keyword named after the key's leaf (item 3), and a keyword left out or passed nil resolves
  # through I18n at render time, so a locale switch between renders takes effect (rule 3).
  class ChromeOverrideTest < ViewComponent::TestCase
    # CD — Ui::ConfirmDialogComponent, the shape the others follow.

    test 'CD1 a call-site label wins over the locale file' do
      render_inline(Ui::ConfirmDialogComponent.new(confirm_label: 'Delete it', cancel_label: 'Keep it'))

      assert_selector 'button[value=confirm]', text: 'Delete it'
      assert_selector 'button[value=cancel]', text: 'Keep it'
    end

    test 'CD2 nil falls through to the locale file rather than rendering nothing' do
      render_inline(Ui::ConfirmDialogComponent.new(title: nil, confirm_label: nil))

      assert_selector '[data-ui--dialog-title]', text: I18n.t('rails_ui_kit.confirm_dialog.title')
      assert_selector 'button[value=confirm]', text: I18n.t('rails_ui_kit.confirm_dialog.confirm_label')
    end

    test 'CD3 the locale file wins over nothing, per render' do
      I18n.with_locale(:fr) do
        render_inline(Ui::ConfirmDialogComponent.new)

        assert_selector 'button[value=confirm]', text: 'Confirmer'
        assert_selector 'button[value=cancel]', text: 'Annuler'
      end
    end

    # MO — Ui::ModalComponent. Its chrome reaches ui--modal as data attributes, so the call
    # site's value has to travel the same path the translation does (§ Behavior, item 5).

    test 'MO1 a call-site prompt wins, and reaches the controller values' do
      render_inline(Ui::ModalComponent.new(track_changes: true,
                                           unsaved_changes_title: 'Hold on',
                                           unsaved_changes_message: 'Really discard?'))

      root = page.find('div[data-controller]')
      assert_equal 'Hold on', root['data-ui--modal-unsaved-changes-title-value']
      assert_equal 'Really discard?', root['data-ui--modal-unsaved-changes-message-value']
    end

    test 'MO2 without a keyword the prompt is the locale file, per render' do
      I18n.with_locale(:fr) do
        render_inline(Ui::ModalComponent.new(track_changes: true))

        root = page.find('div[data-controller]')
        assert_equal 'Modifications non enregistrées', root['data-ui--modal-unsaved-changes-title-value']
        assert_equal I18n.t('rails_ui_kit.modal.unsaved_changes_message'),
                     root['data-ui--modal-unsaved-changes-message-value']
      end
    end

    # TO — Ui::ToastComponent and Ui::ToastContainerComponent. The container matters on its own
    # because window.triggerToast clones the templates it renders, so a per-instance close label
    # that only reached Ui::ToastComponent would never reach a toast JavaScript creates.

    test 'TO1 a call-site close label wins over the locale file' do
      render_inline(Ui::ToastComponent.new(type: :info, message: 'Saved', close_label: 'Dismiss'))

      assert_equal 'Dismiss', page.find('button')['aria-label']
    end

    test 'TO2 the container passes its close label into every template toast' do
      render_inline(Ui::ToastContainerComponent.new(close_label: 'Dismiss', default_title: 'Heads up'))

      assert_equal 'Heads up', page.find('div[data-controller=ui--toast-container]')['data-ui--toast-container-default-title-value']
      assert_equal ['Dismiss'] * Ui::ToastComponent::TYPES.size, template_close_labels
    end

    test 'TO3 without keywords the container and its toasts read the locale file, per render' do
      I18n.with_locale(:fr) do
        render_inline(Ui::ToastContainerComponent.new)

        container = page.find('div[data-controller=ui--toast-container]')
        assert_equal 'Avis', container['data-ui--toast-container-default-title-value']
        assert_equal ['Fermer la notification'] * Ui::ToastComponent::TYPES.size, template_close_labels
      end
    end

    test 'TO5 actions_hint and region_label win per instance, and reach the attributes the controllers read' do
      render_inline(Ui::ToastContainerComponent.new(actions_hint: 'F8 for actions.', region_label: 'Alerts'))

      assert_equal 'F8 for actions.', page.find('[data-slot=toast-container]')['data-ui--toast-container-actions-hint-value']
      assert_equal 'Alerts', page.find('#ui-toasts', visible: :all)['aria-label']

      I18n.with_locale(:fr) do
        render_inline(Ui::ToastContainerComponent.new)
        assert_equal I18n.t('rails_ui_kit.toast.actions_hint'), page.find('[data-slot=toast-container]')['data-ui--toast-container-actions-hint-value']
        assert_equal 'Notifications', page.find('#ui-toasts', visible: :all)['aria-label']
      end
    end

    test 'TO4 a toast with no message still takes a call-site default title' do
      render_inline(Ui::ToastComponent.new(type: :info, message: nil, default_title: 'Heads up'))

      assert_selector "[data-ui--toast-target='title']", text: 'Heads up'
    end

    # SE — Ui::SelectComponent. Its chrome keywords must not leak into the <select> or the root
    # as HTML attributes, which is what an unconsumed keyword does in Ui::Base.

    test 'SE1 call-site chrome wins for the empty state and the search placeholder' do
      render_inline(Ui::SelectComponent.new(name: 'post[state]', search: true, options: %w[a b],
                                            no_results: 'Nothing matches', search_placeholder: 'Find a state'))

      assert_selector '#post_state-empty', text: 'Nothing matches', visible: :all
      assert_selector "#post_state-search[placeholder='Find a state']", visible: :all
      assert_no_selector '[no_results]', visible: :all
      assert_no_selector '[search-placeholder]', visible: :all
    end

    test 'SE2 without keywords Select reads the locale file, per render' do
      I18n.with_locale(:fr) do
        render_inline(Ui::SelectComponent.new(name: 'post[state]', search: true, options: %w[a b]))

        assert_selector '#post_state-empty', text: 'Aucun résultat', visible: :all
        assert_selector "#post_state-search[placeholder='Rechercher…']", visible: :all
      end
    end

    # FI — Ui::FieldComponent's character-counter chrome, rendered when the bound control asks
    # for one (ui-character-counter § Behavior, items 10-11).

    def render_counter_field(**overrides)
      render_inline(Ui::FieldComponent.new(name: 'post[bio]', **overrides)) do |field|
        field.with_control(Ui::TextareaComponent, counter: true, limit: 20)
      end
    end

    def counter_text
      page.find('[data-ui--character-count-target=count]', visible: :all).text
    end

    test 'FI1 a call-site count: format wins over the locale file' do
      template = "#{I18n.t('rails_ui_kit.character_counter.count')} total"
      render_counter_field(count: template)

      assert_equal format(template, count: 0, limit: 20), counter_text
    end

    test 'FI2 without count: Field reads the locale file, per render' do
      I18n.with_locale(:fr) do
        render_counter_field

        assert_equal I18n.t('rails_ui_kit.character_counter.count', locale: :fr, count: 0, limit: 20), counter_text
      end
    end

    # <template> content is inert, so its buttons aren't in the document Capybara queries; the
    # rendered HTML is (test/components/ui/toast_container_component_test.rb does the same).
    def template_close_labels
      # The per-type toast templates; the container's action templates carry no close button.
      rendered_content.scan(%r{<template data-ui--toast-container-target="template"[^>]*>.*?</template>}m).map do |template|
        template[/aria-label="([^"]*)"/, 1]
      end
    end

    # The inventory's own shape: one name per string (§ Behavior, item 3).

    test 'CH1 every chrome keyword is named after its key leaf' do
      {
        Ui::ConfirmDialogComponent => %w[title message confirm_label cancel_label],
        Ui::ModalComponent => %w[unsaved_changes_title unsaved_changes_message],
        Ui::ToastComponent => %w[close_label default_title],
        Ui::ToastContainerComponent => %w[close_label default_title],
        Ui::SelectComponent => %w[search_placeholder no_results],
        Ui::FieldComponent => %w[required_label count remaining over]
      }.each do |component, keywords|
        accepted = component.instance_method(:initialize).parameters
                            .filter_map { |kind, name| name.to_s if %i[key keyreq].include?(kind) }
        keywords.each do |keyword|
          assert_includes accepted, keyword,
                          "#{component} should take #{keyword}:, the leaf of the key it renders"
        end
      end
    end
  end
end
