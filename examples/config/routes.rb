# frozen_string_literal: true

Rails.application.routes.draw do
  DocsPages::PAGES.each do |page|
    action = DocsPages.action_for(page)

    if page[:slug] == :root
      root to: "docs##{action}"
    else
      get DocsPages.path_for(page), to: "docs##{action}", as: page[:slug]
    end
  end

  # The Modal + Turbo guide's demo resources: real routes, real actions, real 422s. Every route
  # sample in docs/guides/modal-and-turbo.md is one of these.
  resources :projects, path: 'demos/projects', only: %i[show edit update destroy] do
    get :activity, on: :member
  end
  resources :invitations, path: 'demos/invitations', only: %i[new create]

  # docs/guides/forms.md's demo resource: a real edit and update, with a real 422.
  resources :members, path: 'demos/members', only: %i[edit update]

  get    'demos/modal',  to: 'docs#modal_demo',   as: :modal_demo
  post   'demos/submit', to: 'docs#demo_submit',  as: :demo_submit
  post   'demos/select', to: 'docs#select_submit', as: :demo_select
  post   'demos/field',  to: 'docs#field_submit',  as: :demo_field
  post   'demos/choices', to: 'docs#choices_submit', as: :demo_choices
  delete 'demos/item',   to: 'docs#demo_delete',  as: :demo_delete

  # The Toast page's demo endpoints: a Turbo Stream toast, a flash toast across a redirect, and
  # the PATCH an Undo action sends.
  post  'demos/toasts',      to: 'toasts#create', as: :demo_toasts
  get   'demos/toasts/flash', to: 'toasts#flash_toast', as: :demo_toast_flash
  patch 'demos/toasts/undo', to: 'toasts#undo', as: :demo_toast_undo
end
