# frozen_string_literal: true

# Importmap pins shipped by rails-ui-kit.
# Consumers using importmap-rails get these automatically via the engine initializer.
# Override any pin in your application's config/importmap.rb if needed.

# Floating UI reaches importmap consumers as one pin, not four, and it is vendored rather than
# fetched from jsDelivr: the +esm build once at this pin looked like one CDN dependency but
# wasn't -- its own module graph re-imports @floating-ui/core and @floating-ui/utils from
# jsDelivr by URL, so jsDelivr being unreachable took Turbo, Stimulus and every anchored
# component down with it, not just positioning. `vendor/floating-ui.dom.js` bundles all three at
# the versions this pin named (1.6.1/1.6.0/0.2.1) into one file with no remaining imports; see its
# header comment for the update procedure.
pin '@floating-ui/dom', to: 'rails_ui_kit/vendor/floating-ui.dom.js'
pin_all_from File.expand_path('../app/javascript/rails_ui_kit/vendor', __dir__),
             under: 'rails_ui_kit/vendor',
             to: 'rails_ui_kit/vendor'

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
