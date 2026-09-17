# frozen_string_literal: true

# Runs a block as a toast payload is validated outside development and test: nothing raises, each
# broken rule is logged, and the safe rule applies (ui-toast § Behavior, item 15). Yields the log.
module LenientToasts
  def leniently
    original = Ui::Toast::Validation.method(:strict?)
    logger = Rails.logger
    log = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(log)
    Ui::Toast::Validation.define_singleton_method(:strict?) { false }
    yield log
  ensure
    Rails.logger = logger
    Ui::Toast::Validation.define_singleton_method(:strict?, original)
  end
end
