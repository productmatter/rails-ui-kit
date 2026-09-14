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

  get    'demos/modal',  to: 'docs#modal_demo',   as: :modal_demo
  post   'demos/submit', to: 'docs#demo_submit',  as: :demo_submit
  post   'demos/select', to: 'docs#select_submit', as: :demo_select
  delete 'demos/item',   to: 'docs#demo_delete',  as: :demo_delete
end
