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
# Sections group pages by the job you're doing; :prefix is the page's URL prefix, carried
# per page rather than per section, so a page can be regrouped without its path changing.
# A Turbo or Rails helper sits with the component it serves rather than in a bucket of
# its own -- Turbo Confirm beside Confirm Dialog, Form Change beside the form controls.
#
# This lives in config/initializers so it's loaded before routes.rb is drawn and
# before DocsController/the layout are autoloaded, with no explicit require anywhere.
module DocsPages
  PAGES = [
    { slug: :root, title: 'Introduction', section: 'Getting Started', path: '/', action: :index },
    { slug: :installation, title: 'Installation', section: 'Getting Started' },
    { slug: :theming, prefix: 'guides', title: 'Theming', section: 'Getting Started',
      summary: 'Tokens in light and dark, control heights, class merging and chrome strings: how an app makes the kit its own.' },
    { slug: :dark_mode, prefix: 'utilities', title: 'Dark Mode', section: 'Getting Started',
      summary: 'A persisted light and dark toggle, synced across tabs.' },
    { slug: :i18n, prefix: 'utilities', title: 'Internationalization', section: 'Getting Started',
      summary: 'Every string the kit renders lives in a locale file your app can override.' },

    { slug: :forms_guide, path: 'guides/forms', title: 'Building a form', section: 'Forms',
      summary: 'A form bound to its record, end to end: enums, belongs_to, has_many ids, nested attributes, ' \
               'the 422 and the submitting state. The companion guide ships inside the gem.' },
    { slug: :field, prefix: 'components', title: 'Field', section: 'Forms',
      summary: 'Wires a label, control, description and errors into one accessible unit, deriving every id from the attribute name.' },
    { slug: :select, prefix: 'components', title: 'Select', section: 'Forms',
      summary: 'A select built from a Rails collection, enum or options hash: a real <select> that submits, ' \
               'mirrored into a WAI-ARIA combobox with full keyboard support.' },
    { slug: :choices, prefix: 'components', title: 'Choices', section: 'Forms',
      summary: 'A radio or checkbox group over real inputs, with collection_radio_buttons / collection_check_boxes ' \
               'names, ids and hidden field, in a list or card variant.' },
    { slug: :input, prefix: 'components', title: 'Input', section: 'Forms',
      summary: 'A native <input> drawn from the design tokens, with invalid and disabled states read from the element itself.' },
    { slug: :textarea, prefix: 'components', title: 'Textarea', section: 'Forms',
      summary: 'A native <textarea> with the same token styling and states as Input.' },
    { slug: :label, prefix: 'components', title: 'Label', section: 'Forms',
      summary: 'A native <label>, dimmed when the control it names is disabled.' },
    { slug: :button, prefix: 'components', title: 'Button', section: 'Forms',
      summary: 'Six variants and four sizes. Renders a link when given href:, and a disabled link is inert without JavaScript.' },
    { slug: :form_change, prefix: 'utilities', title: 'Form Change', section: 'Forms',
      summary: 'Tracks whether a form has unsaved changes and dispatches events when that changes.' },
    { slug: :turbo_disable_with, prefix: 'utilities', title: 'Turbo Disable With', section: 'Forms',
      summary: 'Disables form buttons during Turbo submissions and shows a loading state.' },
    { slug: :character_counter, prefix: 'utilities', title: 'Character Counter', section: 'Forms',
      summary: 'A soft, live count against a Textarea(counter:, limit:), rendered as help text and announced at three thresholds.' },

    { slug: :modal, prefix: 'components', title: 'Modal', section: 'Overlays',
      summary: 'A modal that opens when rendered, driven by Turbo Frames and Streams, with an optional guard for unsaved changes.' },
    { slug: :modal_turbo, prefix: 'guides', title: 'Modal & Turbo', section: 'Overlays',
      summary: 'The full Turbo lifecycle of a modal: opened by a stream, re-rendered in a content frame, ' \
               'closed by the server. The companion guide ships inside the gem.' },
    { slug: :dropdown, prefix: 'components', title: 'Dropdown', section: 'Overlays',
      summary: 'An anchored menu or dialog that follows the WAI-ARIA menu button pattern: arrow keys, Home/End, typeahead and Escape.' },
    { slug: :popover, prefix: 'components', title: 'Popover', section: 'Overlays',
      summary: 'A click-triggered anchored panel for rich content, closed by clicking outside or pressing Escape.' },
    { slug: :tooltip, prefix: 'components', title: 'Tooltip', section: 'Overlays',
      summary: 'A text hint shown on hover and focus, anchored to its trigger and exposed through aria-describedby.' },

    { slug: :toast, prefix: 'components', title: 'Toast', section: 'Feedback',
      summary: 'Auto-dismissing notifications in five types, announced to screen readers and sendable from a Turbo Stream.' },
    { slug: :confirm_dialog, prefix: 'components', title: 'Confirm Dialog', section: 'Feedback',
      summary: 'A native <dialog> confirmation that returns a Promise, so it can replace window.confirm() and Turbo\'s confirm.' },
    { slug: :turbo_confirm, prefix: 'utilities', title: 'Turbo Confirm', section: 'Feedback',
      summary: 'Replaces Turbo\'s native confirm dialog with the kit\'s own.' },

    { slug: :primitives_overlay, prefix: 'utilities', title: 'Overlay & Presence', section: 'Primitives',
      summary: 'ui--overlay and ui--presence: top layer, focus, scroll lock, dismissal and exit animations.' },
    { slug: :primitives_navigation, prefix: 'utilities', title: 'Positioning & Navigation', section: 'Primitives',
      summary: 'ui--anchor and ui--roving-focus: anchored positioning and keyboard navigation for your own widgets.' }
  ].freeze

  SECTIONS = ['Getting Started', 'Forms', 'Overlays', 'Feedback', 'Primitives'].freeze

  def self.path_for(page)
    page[:path] || [page[:prefix], page[:slug]].compact.join('/')
  end

  def self.action_for(page)
    page[:action] || page[:slug]
  end

  def self.in_section(name)
    PAGES.select { |page| page[:section] == name }
  end
end
