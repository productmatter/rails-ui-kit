# frozen_string_literal: true

# Single source of truth for the docs site's pages. routes.rb, DocsController, and
# the sidebar nav in layouts/docs.html.erb are all generated from PAGES, so adding a
# page is: add its view at app/views/docs/<slug>.html.erb, then one entry below.
#
# An entry needs :slug, :title and :section, and every Components or Utilities entry also
# needs a one-line :summary, which the Introduction page lists. :path and :action are overrides
# for the two pages that don't fit the "<section prefix>/<slug>" / action-is-slug
# pattern (root's path is "/" and its action is :index).
#
# This lives in config/initializers so it's loaded before routes.rb is drawn and
# before DocsController/the layout are autoloaded, with no explicit require anywhere.
module DocsPages
  PAGES = [
    { slug: :root, title: 'Introduction', section: 'Getting Started', path: '/', action: :index },
    { slug: :installation, title: 'Installation', section: 'Getting Started' },

    { slug: :button, title: 'Button', section: 'Components',
      summary: 'Six variants and four sizes. Renders a link when given href:, and a disabled link is inert without JavaScript.' },
    { slug: :confirm_dialog, title: 'Confirm Dialog', section: 'Components',
      summary: 'A native <dialog> confirmation that returns a Promise, so it can replace window.confirm() and Turbo\'s confirm.' },
    { slug: :dropdown, title: 'Dropdown', section: 'Components',
      summary: 'An anchored menu or dialog that follows the WAI-ARIA menu button pattern: arrow keys, Home/End, typeahead and Escape.' },
    { slug: :field, title: 'Field', section: 'Components',
      summary: 'Wires a label, control, description and errors into one accessible unit, deriving every id from the attribute name.' },
    { slug: :input, title: 'Input', section: 'Components',
      summary: 'A native <input> drawn from the design tokens, with invalid and disabled states read from the element itself.' },
    { slug: :label, title: 'Label', section: 'Components',
      summary: 'A native <label>, dimmed when the control it names is disabled.' },
    { slug: :modal, title: 'Modal', section: 'Components',
      summary: 'A modal that opens when rendered, driven by Turbo Frames and Streams, with an optional guard for unsaved changes.' },
    { slug: :popover, title: 'Popover', section: 'Components',
      summary: 'A click-triggered anchored panel for rich content, closed by clicking outside or pressing Escape.' },
    { slug: :textarea, title: 'Textarea', section: 'Components',
      summary: 'A native <textarea> with the same token styling and states as Input.' },
    { slug: :toast, title: 'Toast', section: 'Components',
      summary: 'Auto-dismissing notifications in five types, announced to screen readers and sendable from a Turbo Stream.' },
    { slug: :tooltip, title: 'Tooltip', section: 'Components',
      summary: 'A text hint shown on hover and focus, anchored to its trigger and exposed through aria-describedby.' },

    { slug: :dark_mode, title: 'Dark Mode', section: 'Utilities',
      summary: 'A persisted light and dark toggle, synced across tabs.' },
    { slug: :form_change, title: 'Form Change', section: 'Utilities',
      summary: 'Tracks whether a form has unsaved changes and dispatches events when that changes.' },
    { slug: :i18n, title: 'Internationalization', section: 'Utilities',
      summary: 'Every string the kit renders lives in a locale file your app can override.' },
    { slug: :media_query, title: 'Media Query', section: 'Utilities',
      summary: 'A matchMedia watcher that writes a data attribute, toggles a class and dispatches a change event.' },
    { slug: :primitives_navigation, title: 'Positioning & Navigation', section: 'Utilities',
      summary: 'ui--anchor and ui--roving-focus: anchored positioning and keyboard navigation for your own widgets.' },
    { slug: :primitives_overlay, title: 'Overlay & Presence', section: 'Utilities',
      summary: 'ui--overlay and ui--presence: top layer, focus, scroll lock, dismissal and exit animations.' },
    { slug: :turbo_confirm, title: 'Turbo Confirm', section: 'Utilities',
      summary: 'Replaces Turbo\'s native confirm dialog with the kit\'s own.' },
    { slug: :turbo_disable_with, title: 'Turbo Disable With', section: 'Utilities',
      summary: 'Disables form buttons during Turbo submissions and shows a loading state.' }
  ].freeze

  SECTIONS = ['Getting Started', 'Components', 'Utilities'].freeze

  PREFIXES = { 'Components' => 'components', 'Utilities' => 'utilities' }.freeze

  def self.path_for(page)
    page[:path] || [PREFIXES[page[:section]], page[:slug]].compact.join('/')
  end

  def self.action_for(page)
    page[:action] || page[:slug]
  end

  def self.in_section(name)
    PAGES.select { |page| page[:section] == name }
  end
end
