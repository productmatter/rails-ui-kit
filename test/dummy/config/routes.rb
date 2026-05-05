# frozen_string_literal: true

Rails.application.routes.draw do
  root to: proc { [200, {}, ['rails-ui-kit dummy']] }
end
