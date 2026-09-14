# frozen_string_literal: true

require 'rails/generators/base'

module RailsUiKit
  module Generators
    # Opt-in, and separate from `rails_ui_kit:install` on purpose: installing a gem is no reason
    # to write into a host's .claude/ or AGENTS.md.
    #
    # What it writes is a pointer, never a copy. The guide lives in the installed gem, so a host
    # that upgrades rails_ui_kit gets the new guide the next time an agent reads it -- where a
    # copied-in guide would quietly go on describing the version it was copied from.
    class AgentSkillGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      SKILL_PATH = '.claude/skills/rails-ui-kit/SKILL.md'
      AGENTS_PATH = 'AGENTS.md'
      GUIDES_PATH = 'docs/guides/'
      # One line, for agents that read AGENTS.md rather than Claude Code's skills. It names the
      # same installed-gem location the skill does.
      POINTER = "- **rails_ui_kit**: read the kit's own guide before building or changing one of " \
                'its components, from the installed gem rather than a copy — ' \
                "`$(bundle info --path rails_ui_kit)/#{GUIDES_PATH}` " \
                '(start with `modal-and-turbo.md` for modals and Turbo-driven overlays).'.freeze

      desc 'Point this app\'s coding agents at the rails_ui_kit guides in the installed gem'

      def create_skill
        copy_file 'SKILL.md', SKILL_PATH
      end

      def point_agents_file
        return create_file(AGENTS_PATH, "#{POINTER}\n") unless File.exist?(destination_path(AGENTS_PATH))

        # Idempotent without help: Thor leaves a file that already contains this line alone, and
        # reports it as unchanged.
        append_to_file AGENTS_PATH, "\n#{POINTER}\n"
      end

      def print_next_steps
        say ''
        say "  Claude Code picks up #{SKILL_PATH} automatically.", :green
        say '  Both the skill and the AGENTS.md line point at the guides in the installed gem,', :green
        say '  so upgrading rails_ui_kit updates what your agents read. Re-run this after an', :green
        say '  upgrade only if you want the skill file itself refreshed.', :green
        say ''
      end

      private

      def destination_path(relative_path)
        File.join(destination_root, relative_path)
      end
    end
  end
end
