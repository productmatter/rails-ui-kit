# frozen_string_literal: true

module ApplicationHelper
  # A step of the control scale written the way a call site has to write it: `:sm`, but
  # `:"2xl"`, because a symbol literal can't start with a digit.
  def control_size_literal(step)
    step.to_s.match?(/\A[a-z_]/) ? ":#{step}" : %(:"#{step}")
  end

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
