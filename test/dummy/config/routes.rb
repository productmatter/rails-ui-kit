# frozen_string_literal: true

Rails.application.routes.draw do
  root to: 'docs#index'

  get 'installation', to: 'docs#installation'

  get 'components/modal',          to: 'docs#modal',          as: :modal
  get 'components/dropdown',       to: 'docs#dropdown',       as: :dropdown
  get 'components/tooltip',        to: 'docs#tooltip',        as: :tooltip
  get 'components/popover',        to: 'docs#popover',        as: :popover
  get 'components/toast',          to: 'docs#toast',          as: :toast
  get 'components/confirm_dialog', to: 'docs#confirm_dialog', as: :confirm_dialog

  get 'utilities/dark_mode',          to: 'docs#dark_mode',          as: :dark_mode
  get 'utilities/form_change',        to: 'docs#form_change',        as: :form_change
  get 'utilities/turbo_confirm',      to: 'docs#turbo_confirm',      as: :turbo_confirm
  get 'utilities/turbo_disable_with', to: 'docs#turbo_disable_with', as: :turbo_disable_with

  get 'demos/modal', to: 'docs#modal_demo', as: :modal_demo
end
