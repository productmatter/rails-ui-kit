# frozen_string_literal: true

module ApplicationHelper
  def nav_link(name, path)
    active = current_page?(path)
    link_to name, path, class: [
      'block rounded px-2 py-1 text-sm transition-colors ' \
      'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-sidebar-ring',
      active ? 'bg-sidebar-accent text-sidebar-accent-foreground font-medium'
             : 'text-muted-foreground hover:text-sidebar-foreground hover:bg-sidebar-accent/50'
    ].join(' ')
  end
end
