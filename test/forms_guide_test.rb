# frozen_string_literal: true

require 'test_helper'

# docs/guides/forms.md promises that every sample in it is code the demo runs. As with the Modal
# and Turbo guide (test/modal_and_turbo_guide_test.rb), each fenced sample names the file it came
# from and has to be a verbatim, contiguous slice of it.
class FormsGuideTest < ActiveSupport::TestCase
  ROOT = File.expand_path('..', __dir__)
  GUIDE = File.join(ROOT, 'docs/guides/forms.md')

  # A sample from each step the guide teaches. A guide that stopped quoting one of these would
  # still pass the drift check -- by saying nothing about it.
  QUOTED_SOURCES = %w[
    examples/config/routes.rb
    examples/app/controllers/members_controller.rb
    examples/app/views/members/_form.html.erb
    examples/app/views/members/edit.html.erb
    test/system/forms_guide_test.rb
  ].freeze

  # The sections the Choices spec and the guide's brief require, by the words a reader looks for.
  REQUIRED_PASSAGES = [
    'A locked checkbox is not authorization',
    'errors: member.errors[:roles]',
    'errors: member.errors[:team_id] + member.errors[:team]',
    'name: address_form.field_name(:city)',
    'enum: :status',
    'status: :unprocessable_entity',
    'turbo_disable_with',
    'ui_select'
  ].freeze

  def self.blocks
    @blocks ||= File.read(GUIDE).scan(/^```(\w+)([^\n]*)\n(.*?)^```$/m).map do |language, info, body|
      [language, info[/title="([^"]+)"/, 1], body]
    end
  end

  test 'the guide exists and is packaged in the gem' do
    assert File.exist?(GUIDE)
    files = Gem::Specification.load(File.join(ROOT, 'rails_ui_kit.gemspec')).files
    assert_includes files, 'docs/guides/forms.md', 'the guide is not in spec.files, so it would not ship in a built gem'
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

  test 'the guide quotes every demo file the form is built from' do
    assert_empty QUOTED_SOURCES - blocks.filter_map { |_, title, _| title }.uniq,
                 'the guide stopped quoting part of the demo it documents'
  end

  test 'the guide still teaches each shape it promises' do
    guide = File.read(GUIDE)

    assert_empty(REQUIRED_PASSAGES.reject { |passage| guide.include?(passage) })
  end

  # README's Usage section is a slice of the same demo, so it can't teach a form the demo doesn't run.
  test 'every titled sample in the README is a verbatim slice of the file it names' do
    readme = File.read(File.join(ROOT, 'README.md')).scan(/^```(\w+)([^\n]*)\n(.*?)^```$/m)
    titled = readme.filter_map { |_, info, body| [info[/title="([^"]+)"/, 1], body] if info.include?('title=') }

    assert_includes titled.map(&:first), 'examples/app/views/members/_form.html.erb'
    titled.each do |title, body|
      assert_includes normalise(File.read(File.join(ROOT, title))), normalise(body),
                      "README's sample from #{title} is not in that file any more:\n#{body}"
    end
  end

  def blocks
    self.class.blocks
  end

  def normalise(text)
    "#{text.lines.map(&:rstrip).join("\n")}\n"
  end
end
