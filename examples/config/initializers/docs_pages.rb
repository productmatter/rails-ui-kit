# frozen_string_literal: true

# Single source of truth for the docs site's pages. routes.rb, DocsController, and
# the sidebar nav in layouts/docs.html.erb are all generated from PAGES, so adding a
# page is: add its view at app/views/docs/<slug>.html.erb, then one entry below.
#
# An entry only needs :slug, :title and :section. :path and :action are overrides
# for the two pages that don't fit the "<section prefix>/<slug>" / action-is-slug
# pattern (root's path is "/" and its action is :index).
#
# This lives in config/initializers so it's loaded before routes.rb is drawn and
# before DocsController/the layout are autoloaded, with no explicit require anywhere.
module DocsPages
  PAGES = [
    { slug: :root, title: 'Introduction', section: 'Getting Started', path: '/', action: :index },
    { slug: :installation, title: 'Installation', section: 'Getting Started' },

    { slug: :alert, title: 'Alert', section: 'Components' },
    { slug: :aspect_ratio, title: 'Aspect Ratio', section: 'Components' },
    { slug: :avatar, title: 'Avatar', section: 'Components' },
    { slug: :badge, title: 'Badge', section: 'Components' },
    { slug: :breadcrumb, title: 'Breadcrumb', section: 'Components' },
    { slug: :button, title: 'Button', section: 'Components' },
    { slug: :button_group, title: 'Button Group', section: 'Components' },
    { slug: :card, title: 'Card', section: 'Components' },
    { slug: :confirm_dialog, title: 'Confirm Dialog', section: 'Components' },
    { slug: :dropdown, title: 'Dropdown', section: 'Components' },
    { slug: :empty, title: 'Empty', section: 'Components' },
    { slug: :field, title: 'Field', section: 'Components' },
    { slug: :input, title: 'Input', section: 'Components' },
    { slug: :input_group, title: 'Input Group', section: 'Components' },
    { slug: :item, title: 'Item', section: 'Components' },
    { slug: :kbd, title: 'Kbd', section: 'Components' },
    { slug: :label, title: 'Label', section: 'Components' },
    { slug: :modal, title: 'Modal', section: 'Components' },
    { slug: :native_select, title: 'Native Select', section: 'Components' },
    { slug: :pagination, title: 'Pagination', section: 'Components' },
    { slug: :popover, title: 'Popover', section: 'Components' },
    { slug: :progress, title: 'Progress', section: 'Components' },
    { slug: :separator, title: 'Separator', section: 'Components' },
    { slug: :skeleton, title: 'Skeleton', section: 'Components' },
    { slug: :spinner, title: 'Spinner', section: 'Components' },
    { slug: :table, title: 'Table', section: 'Components' },
    { slug: :textarea, title: 'Textarea', section: 'Components' },
    { slug: :toast, title: 'Toast', section: 'Components' },
    { slug: :tooltip, title: 'Tooltip', section: 'Components' },

    { slug: :dark_mode, title: 'Dark Mode', section: 'Utilities' },
    { slug: :form_change, title: 'Form Change', section: 'Utilities' },
    { slug: :media_query, title: 'Media Query', section: 'Utilities' },
    { slug: :primitives_navigation, title: 'Positioning & Navigation', section: 'Utilities' },
    { slug: :primitives_overlay, title: 'Overlay & Presence', section: 'Utilities' },
    { slug: :turbo_confirm, title: 'Turbo Confirm', section: 'Utilities' },
    { slug: :turbo_disable_with, title: 'Turbo Disable With', section: 'Utilities' }
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
