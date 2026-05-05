# frozen_string_literal: true

require_relative 'lib/rails_ui_kit/version'

Gem::Specification.new do |spec|
  spec.name        = 'rails_ui_kit'
  spec.version     = RailsUiKit::VERSION
  spec.authors     = ['Product Matter']
  spec.email       = ['dev@productmatter.com']
  spec.homepage    = 'https://github.com/productmatter/rails-ui-kit'
  spec.summary     = 'Reusable Rails UI components: ViewComponents paired with Stimulus controllers.'
  spec.description = 'A Rails Engine packaging Modal, Dropdown, ConfirmDialog, and Toast components ' \
                     'as ViewComponents with Stimulus controllers, plus utility controllers for ' \
                     'form-change tracking, Turbo confirm/disable-with, and dark mode.'
  spec.license     = 'MIT'

  spec.required_ruby_version = '>= 3.1'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir[
    '{app,config,lib}/**/*',
    'MIT-LICENSE',
    'Rakefile',
    'README.md',
    'package.json'
  ]

  spec.add_dependency 'rails', '>= 7.0'
  spec.add_dependency 'stimulus-rails'
  spec.add_dependency 'turbo-rails'
  spec.add_dependency 'view_component', '>= 3.0', '< 5.0'
end
