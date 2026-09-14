# frozen_string_literal: true

# Importmap pins shipped by rails-ui-kit.
# Consumers using importmap-rails get these automatically via the engine initializer.
# Override any pin in your application's config/importmap.rb if needed.

# Floating UI reaches importmap consumers as one pin, not four. jsDelivr's +esm build carries
# @floating-ui/core and @floating-ui/utils inside its own module graph as origin-absolute
# /npm/... URLs, which resolve without an importmap entry of their own. One pin means the version
# set moves -- and is overridden by a host app -- as a unit, so the skew that four hand-maintained
# pins allow (a host overriding dom alone onto the kit's older core) cannot happen.
pin '@floating-ui/dom', to: 'https://cdn.jsdelivr.net/npm/@floating-ui/dom@1.6.1/+esm'

pin 'rails-ui-kit', to: 'rails_ui_kit/index.js'
pin_all_from File.expand_path('../app/javascript/rails_ui_kit/controllers', __dir__),
             under: 'rails_ui_kit/controllers',
             to: 'rails_ui_kit/controllers'

# The overlay primitives' shared modules: page-level behaviour (the scroll-lock reference
# count) and behaviour the controllers compose by import rather than through outlets. Not
# controllers, so not under the pin above.
pin_all_from File.expand_path('../app/javascript/rails_ui_kit/overlay', __dir__),
             under: 'rails_ui_kit/overlay',
             to: 'rails_ui_kit/overlay'
