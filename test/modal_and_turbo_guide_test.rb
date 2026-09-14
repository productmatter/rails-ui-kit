# frozen_string_literal: true

require 'test_helper'

# docs/guides/modal-and-turbo.md is the canonical guide, and its promise is that every sample in
# it is code the demos actually run (ui-modal-turbo § Business rules, rule 4). This is what makes
# that a fact rather than an intention: each fenced sample names the file it came from, and has to
# be a verbatim, contiguous slice of it.
class ModalAndTurboGuideTest < ActiveSupport::TestCase
  ROOT = File.expand_path('..', __dir__)
  GUIDE = File.join(ROOT, 'docs/guides/modal-and-turbo.md')

  # A sample from each lifecycle step and each pattern the guide teaches. A guide that stopped
  # quoting one of these would still pass the drift check above -- by saying nothing about it.
  QUOTED_SOURCES = %w[
    examples/app/views/layouts/docs.html.erb
    examples/config/routes.rb
    examples/app/controllers/projects_controller.rb
    examples/app/controllers/invitations_controller.rb
    examples/app/views/projects/_project.html.erb
    examples/app/views/projects/_details.html.erb
    examples/app/views/projects/_form.html.erb
    examples/app/views/projects/show.turbo_stream.erb
    examples/app/views/projects/show.html.erb
    examples/app/views/projects/edit.turbo_stream.erb
    examples/app/views/projects/edit.html.erb
    examples/app/views/projects/update.turbo_stream.erb
    examples/app/views/projects/destroy.turbo_stream.erb
    examples/app/views/projects/activity.html.erb
    examples/app/views/invitations/_form.html.erb
    examples/app/views/docs/modal_turbo.html.erb
  ].freeze

  # [language, title, body] per fenced block.
  def self.blocks
    @blocks ||= File.read(GUIDE).scan(/^```(\w+)([^\n]*)\n(.*?)^```$/m).map do |language, info, body|
      [language, info[/title="([^"]+)"/, 1], body]
    end
  end

  test 'the guide exists and is packaged in the gem' do
    assert File.exist?(GUIDE)
    files = Gem::Specification.load(File.join(ROOT, 'rails_ui_kit.gemspec')).files
    assert_includes files, 'docs/guides/modal-and-turbo.md',
                    'the guide is not in spec.files, so it would not ship in a built gem'
  end

  test 'every code sample names the file it came from' do
    untitled = blocks.select { |language, title, _| %w[erb ruby].include?(language) && title.nil? }

    assert_empty untitled.map { |_, _, body| body.lines.first },
                 'every erb/ruby sample must carry title="<path>" naming the demo file it quotes'
  end

  test 'every code sample is a verbatim slice of the file it names' do
    blocks.each do |_language, title, body|
      next unless title

      source = File.join(ROOT, title)
      assert File.exist?(source), "#{title} does not exist, but the guide quotes it"
      assert_includes normalise(File.read(source)), normalise(body),
                      "the guide's sample from #{title} is not in that file any more:\n#{body}"
    end
  end

  test 'the guide quotes every demo file the lifecycle is built from' do
    quoted = blocks.filter_map { |_, title, _| title }.uniq

    assert_empty QUOTED_SOURCES - quoted,
                 'the guide stopped quoting part of the demo it documents'
  end

  test 'the guide has samples at all' do
    assert_operator blocks.count { |_, title, _| title }, :>=, 15
  end

  def blocks
    self.class.blocks
  end

  # Trailing whitespace is the only difference tolerated: it is invisible in both files and is
  # what an editor strips on save.
  def normalise(text)
    "#{text.lines.map(&:rstrip).join("\n")}\n"
  end
end
