# frozen_string_literal: true

module Ui
  # Chrome is what the kit says in its own voice — a close button's accessible name, an empty
  # state, the unsaved-changes prompt — as opposed to content, which the call site writes and
  # the host translates through its own locale files. Only chrome lives in
  # `config/locales/rails_ui_kit.en.yml` (ui-localization § Behavior, item 1).
  #
  # Every chrome string resolves call site → host locale file → kit default. The host's own
  # `config/locales` is loaded after every engine's, so a host key already wins app-wide; this
  # is the per-instance half of that chain.
  module Chrome
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Declares one chrome string. The keyword a component takes is the key's leaf, so the
      # YAML, the Ruby keyword and the docs table cannot disagree (§ Behavior, item 3).
      #
      #   chrome_string :close_label, key: 'toast.close_label'
      #
      # Resolution happens per render rather than at class-load time, so a locale switch
      # between two renders in one process takes effect (§ Business rules, rule 3). nil means
      # "not given" and falls through to the locale file; a caller passing an empty string
      # means it.
      def chrome_string(name, key:)
        define_method(name) do
          given = instance_variable_get(:"@#{name}")
          given.nil? ? I18n.t("rails_ui_kit.#{key}") : given
        end
      end

      # Declares a chrome string whose count isn't known until the browser knows it. The whole
      # plural map goes over — every category the locale defines, which is what `I18n.t` on a
      # pluralization key returns — and JavaScript picks one with `Intl.PluralRules`
      # (§ Behavior, item 6). A call site replaces the map whole: merging its forms into a
      # locale's would mix two languages in one sentence (item 10).
      def chrome_plural(name, key:)
        define_method(name) do
          given = instance_variable_get(:"@#{name}")
          forms = (given || I18n.t("rails_ui_kit.#{key}")).to_h.symbolize_keys

          unless forms[:other].present?
            raise ArgumentError, "#{name}: needs at least an :other form — every locale has that " \
                                 'category, and it is what an unmatched count falls back to'
          end

          forms
        end
      end
    end

    # The locale that resolved these strings, as a BCP 47 tag, so the browser picks plural
    # categories with the rules of the language the strings are actually in (§ Behavior, item 7).
    # Not read from <html lang>: the kit does not own that element, and a host that leaves it
    # stale would select French strings with English rules.
    def chrome_locale
      I18n.locale.to_s.tr('_', '-')
    end
  end
end
