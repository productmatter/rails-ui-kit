# frozen_string_literal: true

# Importmap pins shipped by rails-ui-kit.
# Consumers using importmap-rails get these automatically via the engine initializer.
# Override any pin in your application's config/importmap.rb if needed.

pin '@floating-ui/dom',        to: 'https://ga.jspm.io/npm:@floating-ui/dom@1.6.1/dist/floating-ui.dom.mjs'
pin '@floating-ui/core',       to: 'https://ga.jspm.io/npm:@floating-ui/core@1.6.0/dist/floating-ui.core.mjs'
pin '@floating-ui/utils',      to: 'https://ga.jspm.io/npm:@floating-ui/utils@0.2.1/dist/floating-ui.utils.mjs'
pin '@floating-ui/utils/dom',  to: 'https://ga.jspm.io/npm:@floating-ui/utils@0.2.1/dist/floating-ui.utils.dom.mjs'

pin 'rails-ui-kit', to: 'rails_ui_kit/index.js'
pin_all_from File.expand_path('../app/javascript/rails_ui_kit/controllers', __dir__),
             under: 'rails_ui_kit/controllers',
             to: 'rails_ui_kit/controllers'
