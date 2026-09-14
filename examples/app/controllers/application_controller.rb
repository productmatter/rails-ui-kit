# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # The docs app ships English. `?locale=` exists so the kit's own chrome can be seen — and
  # measured by the browser lane — in another language: the fixture locales the test suite
  # loads, and the pseudo-locale (ui-localization § Behavior, item 14). An unknown or absent
  # value is the default locale, so a stray parameter can never 500 a docs page.
  around_action :switch_locale

  private

  def switch_locale(&)
    I18n.with_locale(requested_locale, &)
  end

  def requested_locale
    requested = params[:locale].presence&.to_sym
    I18n.available_locales.include?(requested) ? requested : I18n.default_locale
  end
end
