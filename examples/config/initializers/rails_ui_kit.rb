# frozen_string_literal: true

# The kit keeps its own rule: every modal in the docs app renders its content through
# Ui::ModalContentComponent, so require_content_component is on wherever the app is developed and
# tested. to_prepare, because a code reload in development would otherwise reset it.
Rails.application.config.to_prepare do
  Ui::ModalComponent.require_content_component = Rails.env.local?
end
