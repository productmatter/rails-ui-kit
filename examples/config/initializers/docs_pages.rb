# frozen_string_literal: true

# Single source of truth for the docs site's pages. routes.rb, DocsController, and
# the sidebar nav in layouts/docs.html.erb are all generated from PAGES, so adding a
# page is: add its view at app/views/docs/<slug>.html.erb, then one entry below.
#
# An entry needs :slug, :title and :section, and every entry outside Getting Started also
# needs a one-line :summary, which the Introduction page lists. :path and :action are overrides
# for the two pages that don't fit the "<section prefix>/<slug>" / action-is-slug
# pattern (root's path is "/" and its action is :index).
#
# Sections group pages by what they're for, but PREFIXES maps each section onto one of
# two URL prefixes (or none, for Getting Started) so this grouping can be reorganized
# without changing any page's path.
#
# This lives in config/initializers so it's loaded before routes.rb is drawn and
# before DocsController/the layout are autoloaded, with no explicit require anywhere.
module DocsPages
  PAGES = [
    { slug: :root, title: 'Introduction', section: 'Getting Started', path: '/', action: :index },
    { slug: :installation, title: 'Installation', section: 'Getting Started' },

    { slug: :field, title: 'Field', section: 'Forms',
      summary: 'Wires a label, control, description and errors into one accessible unit, deriving every id from the attribute name.' },
    { slug: :input, title: 'Input', section: 'Forms',
      summary: 'A native <input> drawn from the design tokens, with invalid and disabled states read from the element itself.' },
    { slug: :label, title: 'Label', section: 'Forms',
      summary: 'A native <label>, dimmed when the control it names is disabled.' },
    { slug: :textarea, title: 'Textarea', section: 'Forms',
      summary: 'A native <textarea> with the same token styling and states as Input.' },
    { slug: :select, title: 'Select', section: 'Forms',
      summary: 'A select built from a Rails collection, enum or options hash: a real <select> that submits, ' \
               'mirrored into a WAI-ARIA combobox with full keyboard support.' },

    { slug: :button, title: 'Button', section: 'Actions',
      summary: 'Six variants and four sizes. Renders a link when given href:, and a disabled link is inert without JavaScript.' },
    { slug: :dropdown, title: 'Dropdown', section: 'Actions',
      summary: 'An anchored menu or dialog that follows the WAI-ARIA menu button pattern: arrow keys, Home/End, typeahead and Escape.' },

    { slug: :modal, title: 'Modal', section: 'Overlays',
      summary: 'A modal that opens when rendered, driven by Turbo Frames and Streams, with an optional guard for unsaved changes.' },
    { slug: :confirm_dialog, title: 'Confirm Dialog', section: 'Overlays',
      summary: 'A native <dialog> confirmation that returns a Promise, so it can replace window.confirm() and Turbo\'s confirm.' },
    { slug: :popover, title: 'Popover', section: 'Overlays',
      summary: 'A click-triggered anchored panel for rich content, closed by clicking outside or pressing Escape.' },
    { slug: :tooltip, title: 'Tooltip', section: 'Overlays',
      summary: 'A text hint shown on hover and focus, anchored to its trigger and exposed through aria-describedby.' },

    { slug: :toast, title: 'Toast', section: 'Feedback',
      summary: 'Auto-dismissing notifications in five types, announced to screen readers and sendable from a Turbo Stream.' },

    { slug: :turbo_confirm, title: 'Turbo Confirm', section: 'Rails & Turbo',
      summary: 'Replaces Turbo\'s native confirm dialog with the kit\'s own.' },
    { slug: :turbo_disable_with, title: 'Turbo Disable With', section: 'Rails & Turbo',
      summary: 'Disables form buttons during Turbo submissions and shows a loading state.' },
    { slug: :form_change, title: 'Form Change', section: 'Rails & Turbo',
      summary: 'Tracks whether a form has unsaved changes and dispatches events when that changes.' },
    { slug: :i18n, title: 'Internationalization', section: 'Rails & Turbo',
      summary: 'Every string the kit renders lives in a locale file your app can override.' },

    { slug: :primitives_overlay, title: 'Overlay & Presence', section: 'Primitives & Utilities',
      summary: 'ui--overlay and ui--presence: top layer, focus, scroll lock, dismissal and exit animations.' },
    { slug: :primitives_navigation, title: 'Positioning & Navigation', section: 'Primitives & Utilities',
      summary: 'ui--anchor and ui--roving-focus: anchored positioning and keyboard navigation for your own widgets.' },
    { slug: :media_query, title: 'Media Query', section: 'Primitives & Utilities',
      summary: 'A matchMedia watcher that writes a data attribute, toggles a class and dispatches a change event.' },
    { slug: :dark_mode, title: 'Dark Mode', section: 'Primitives & Utilities',
      summary: 'A persisted light and dark toggle, synced across tabs.' }
  ].freeze

  SECTIONS = ['Getting Started', 'Forms', 'Actions', 'Overlays', 'Feedback', 'Rails & Turbo',
              'Primitives & Utilities'].freeze

  PREFIXES = {
    'Forms' => 'components',
    'Actions' => 'components',
    'Overlays' => 'components',
    'Feedback' => 'components',
    'Rails & Turbo' => 'utilities',
    'Primitives & Utilities' => 'utilities'
  }.freeze

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
