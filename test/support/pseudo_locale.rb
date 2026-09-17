# frozen_string_literal: true

# A pseudo-locale, generated from the shipped English chrome rather than committed as a file,
# so it can never drift from what the kit actually says (ui-localization § Acceptance checks).
#
# Every chrome string comes back bracketed, accented and about 40% longer:
#
#   "No results"  →  "⟦Ñö rësülts····⟧"
#
# Which makes two failures visible at once. A string that renders in plain English under this
# locale never went through I18n — it is hardcoded. And a box that clips, wraps badly or pushes
# its neighbours around at +40% will do the same in German, which runs about 30% longer than
# English (WCAG 1.4.10 territory).
module PseudoLocale
  LOCALE = :'en-XA'
  OPEN = '⟦'
  CLOSE = '⟧'
  PAD = '·'
  EXPANSION = 0.4

  ACCENTS = {
    'a' => 'á', 'b' => 'ƀ', 'c' => 'ç', 'd' => 'ð', 'e' => 'ë', 'f' => 'ƒ', 'g' => 'ğ', 'h' => 'ĥ',
    'i' => 'ï', 'j' => 'ĵ', 'k' => 'ķ', 'l' => 'ł', 'm' => 'ɱ', 'n' => 'ñ', 'o' => 'ö', 'p' => 'þ',
    'q' => 'ǫ', 'r' => 'ř', 's' => 's', 't' => 't', 'u' => 'ü', 'v' => 'ṽ', 'w' => 'ŵ', 'x' => 'ẋ',
    'y' => 'ý', 'z' => 'ž', 'A' => 'Á', 'E' => 'Ë', 'I' => 'Ï', 'N' => 'Ñ', 'O' => 'Ö', 'U' => 'Ü',
    'C' => 'Ç', 'S' => 'Š', 'P' => 'Þ', 'T' => 'Ť', 'D' => 'Ð'
  }.freeze

  # Interpolations stay exactly as they are: %{count} pseudo-translated is a missing count.
  INTERPOLATION = /(%\{[^}]+\})/

  def self.install!(source: File.expand_path('../../config/locales/rails_ui_kit.en.yml', __dir__))
    chrome = YAML.load_file(source).dig('en', 'rails_ui_kit')
    I18n.backend.store_translations(LOCALE, rails_ui_kit: pseudo(chrome))
  end

  def self.pseudo(node)
    case node
    when Hash then node.to_h { |key, value| [key.to_sym, pseudo(value)] }
    when String then decorate(node)
    else node
    end
  end

  def self.decorate(text)
    body = text.split(INTERPOLATION).map { |part| part.match?(INTERPOLATION) ? part : accent(part) }.join
    "#{OPEN}#{body}#{PAD * (text.length * EXPANSION).ceil}#{CLOSE}"
  end

  def self.accent(text)
    text.chars.map { |character| ACCENTS.fetch(character, character) }.join
  end
end
