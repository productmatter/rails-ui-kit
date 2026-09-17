# frozen_string_literal: true

require 'test_helper'
require 'rails/generators/test_case'
require 'generators/rails_ui_kit/agent_skill/agent_skill_generator'
require 'generators/rails_ui_kit/install/install_generator'

module RailsUiKit
  class AgentSkillGeneratorTest < Rails::Generators::TestCase
    tests RailsUiKit::Generators::AgentSkillGenerator
    destination File.expand_path('../tmp/generators', __dir__)
    setup :prepare_destination

    SKILL_PATH = '.claude/skills/rails-ui-kit/SKILL.md'

    test 'Rails finds it as rails_ui_kit:agent_skill' do
      assert_equal RailsUiKit::Generators::AgentSkillGenerator,
                   Rails::Generators.find_by_namespace('rails_ui_kit:agent_skill')
    end

    test 'writes a Claude Code skill at the path Claude Code discovers' do
      run_generator

      assert_file SKILL_PATH do |content|
        assert_match(/^name: rails-ui-kit$/, content)
        assert_match(/^description: .+/, content)
      end
    end

    test "the skill's description triggers on modals, modal forms and Turbo-driven overlays" do
      run_generator

      description = File.read(host_path(SKILL_PATH))[/^description: (.+)$/, 1]
      assert_match(/modal/i, description)
      assert_match(/modal form/i, description)
      assert_match(/turbo/i, description)
    end

    test 'an agent building a form is pointed at the forms guide in the installed gem' do
      run_generator

      skill = File.read(host_path(SKILL_PATH))
      assert_match(/\bform\b/i, skill[/^description: (.+)$/, 1])
      assert_includes skill, 'docs/guides/forms.md'
      assert File.exist?(File.expand_path('../../docs/guides/forms.md', __dir__))
    end

    # The whole design: the skill resolves the guide from the installed gem, so upgrading the gem
    # can never leave a host with instructions for the version it used to have.
    test 'the skill points at the guide in the installed gem and copies none of it' do
      run_generator

      skill = File.read(host_path(SKILL_PATH))
      assert_includes skill, 'bundle info --path rails_ui_kit'
      assert_includes skill, 'docs/guides/modal-and-turbo.md'

      guide = File.read(File.expand_path('../../docs/guides/modal-and-turbo.md', __dir__))
      copied = guide.lines.map(&:strip).select { |line| line.length > 40 }.select { |line| skill.include?(line) }
      assert_empty copied, 'the skill copies guide content instead of pointing at it'
      assert_operator skill.lines.size, :<, guide.lines.size / 4, 'the skill is not thin'
    end

    test 'creates AGENTS.md containing just the pointer line when the host has none' do
      run_generator

      assert_file 'AGENTS.md' do |content|
        assert_equal 1, content.lines.size
        assert_includes content, 'bundle info --path rails_ui_kit'
        assert_includes content, 'docs/guides/'
      end
    end

    test 'appends the pointer to an AGENTS.md the host already has, keeping what is in it' do
      existing = "# How we work\n\n- Run the tests before you push.\n"
      write_host_file('AGENTS.md', existing)

      run_generator

      content = File.read(host_path('AGENTS.md'))
      assert content.start_with?(existing), "the host's own AGENTS.md content was rewritten"
      assert_includes content, 'rails_ui_kit'
    end

    test 're-running changes nothing that is already in place' do
      [-> { write_host_file('AGENTS.md', "# How we work\n") }, -> {}].each do |host_setup|
        prepare_destination
        host_setup.call

        run_generator
        first_agents = File.read(host_path('AGENTS.md'))
        first_skill = File.read(host_path(SKILL_PATH))

        output = run_generator(['--force'])

        assert_equal first_agents, File.read(host_path('AGENTS.md'))
        assert_equal first_skill, File.read(host_path(SKILL_PATH))
        assert_equal 1, File.read(host_path('AGENTS.md')).scan('bundle info --path rails_ui_kit').size
        assert_match(/unchanged\s+AGENTS\.md/, output)
      end
    end

    # rails_ui_kit:install stays quiet: installing a gem is not consent to write into .claude/ or
    # AGENTS.md (ui-modal-turbo § Business rules, rule 6).
    test 'the install generator writes neither the skill nor the AGENTS.md line' do
      write_host_file('app/javascript/application.js', "import { Application } from \"@hotwired/stimulus\"\nconst application = Application.start()\n")
      write_host_file('app/assets/tailwind/application.css', "@import \"tailwindcss\";\n")

      capture(:stdout) do
        Rails::Generators.invoke('rails_ui_kit:install', [], destination_root: destination_root, behavior: :invoke)
      end

      assert_no_file SKILL_PATH
      assert_no_file 'AGENTS.md'
      assert_no_file '.claude'
    end

    private

    def write_host_file(relative_path, contents)
      path = host_path(relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, contents)
    end

    def host_path(relative_path)
      File.join(destination_root, relative_path)
    end
  end
end
