# frozen_string_literal: true

Rails.application.routes.draw do
  # Fly's health check (examples/fly.toml): 200 once the app has booted.
  get 'up', to: 'rails/health#show', as: :rails_health_check

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

  # The stress page (docs/specs/ui-stress-page): a test fixture in a host's layout, not a docs
  # page, so it stays outside DocsPages::PAGES and nothing links to it. /stress/bare is the empty
  # page in the same layout that the kit invariants' self-test plants its faults on.
  get  'stress',      to: 'stress#show', as: :stress
  post 'stress',      to: 'stress#create'
  get  'stress/bare', to: 'stress#bare', as: :stress_bare
  get  'stress/modal', to: 'stress#modal', as: :stress_modal
  post 'stress/toast', to: 'stress#toast', as: :stress_toast
  get  'stress/streams/:target', to: 'stress#stream', as: :stress_stream
end
