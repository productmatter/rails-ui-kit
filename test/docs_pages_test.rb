# frozen_string_literal: true

require 'test_helper'

# Guards the registry in examples/config/initializers/docs_pages.rb against drift
# from the view files it's supposed to describe -- the failure mode this catches is
# a parallel batch of component PRs where someone adds a DocsPages entry with no
# view (a 500 on click) or a view with no entry (unreachable from the sidebar).
class DocsPagesTest < ActiveSupport::TestCase
  DOCS_VIEWS_DIR = File.expand_path('../examples/app/views/docs', __dir__)

  # Views under app/views/docs that are intentionally not DocsPages entries: not a
  # sidebar-navigable page in their own right.
  EXCLUDED_VIEWS = ['modal_demo.turbo_stream.erb'].freeze

  test 'every registry entry has a matching view file' do
    DocsPages::PAGES.each do |page|
      view_name = page[:slug] == :root ? 'index' : page[:slug]
      view_path = File.join(DOCS_VIEWS_DIR, "#{view_name}.html.erb")

      assert File.exist?(view_path), "DocsPages has #{page[:slug].inspect} but #{view_path} does not exist"
    end
  end

  # The Introduction page lists every navigable page straight from the registry, so a
  # missing summary is a blank line there rather than a missing page anywhere.
  test 'every non-Getting-Started entry has a summary' do
    (DocsPages::SECTIONS - ['Getting Started']).each do |section|
      DocsPages.in_section(section).each do |page|
        assert page[:summary].present?,
               "DocsPages entry #{page[:slug].inspect} has no :summary (the Introduction page lists it)"
      end
    end
  end

  test 'every view file is a registry entry or explicitly excluded' do
    registered = DocsPages::PAGES.map { |page| page[:slug] == :root ? 'index.html.erb' : "#{page[:slug]}.html.erb" }

    Dir.children(DOCS_VIEWS_DIR).each do |file|
      next if file.start_with?('_') # partials
      next if EXCLUDED_VIEWS.include?(file)

      assert_includes registered, file,
                      "#{file} exists under app/views/docs but has no DocsPages entry " \
                      '(add one, or add the file to EXCLUDED_VIEWS if it is not a standalone page)'
    end
  end
end
