# frozen_string_literal: true

# The Theming page's swatches, read from the kit's own stylesheet rather than copied into the page,
# so the page can't show a value the kit no longer ships. Both modes are shown at once, which the
# cascade alone can't do: inside a dark page, nothing resets a light panel to :root's values.
module ThemingHelper
  ENGINE_CSS = RailsUiKit::Engine.root.join('app/assets/tailwind/rails_ui_kit/engine.css')

  # { "background" => "oklch(...)", ... } for :light (the :root block) or :dark (the .dark block).
  def kit_token_values(mode)
    css = ENGINE_CSS.read.gsub(%r{/\*.*?\*/}m, '')
    selector = mode == :dark ? '\.dark' : ':root'
    block = css[/^\s*#{selector}\s*\{(.*?)\}/m, 1].to_s
    block.scan(/--([\w-]+):\s*([^;]+);/).to_h
  end

  # The colour tokens: every custom property whose value is a colour, in the stylesheet's order.
  def kit_colour_tokens
    kit_token_values(:light).select { |_, value| value.start_with?('oklch(') }.keys
  end
end
