# frozen_string_literal: true

module ApplicationHelper
  def nav_link(name, path)
    active = current_page?(path)
    link_to name, path, class: [
      'block rounded px-2 py-1 text-sm transition-colors',
      active ? 'bg-neutral-100 dark:bg-neutral-800 text-neutral-900 dark:text-neutral-100 font-medium'
             : 'text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-neutral-100 hover:bg-neutral-50 dark:hover:bg-neutral-900'
    ].join(' ')
  end
end
