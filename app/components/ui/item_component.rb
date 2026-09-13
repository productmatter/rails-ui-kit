# frozen_string_literal: true

module Ui
  # A flexible row: an optional header, media, a title/description pair, actions,
  # and an optional footer, in that fixed order whatever order the caller sets
  # them in (Card). Ui::Item::GroupComponent stacks several, with
  # Ui::Item::SeparatorComponent drawn between them.
  class ItemComponent < Ui::Base
    data_slot 'item'

    # The outline variant's border comes from --input, not --border, for the same
    # reason Badge and Button's outline variant do (ui-presentational-components,
    # Assumptions): it's the only thing marking the row's edge, so it reads as a
    # boundary, not decoration, and needs the same 3:1 the retuned --input token
    # guarantees.
    class_variants(
      base: 'group/item flex flex-wrap items-center rounded-md border border-transparent text-sm transition-colors ' \
            '[a]:transition-colors [a]:hover:bg-accent/50',
      variants: {
        variant: {
          default: 'bg-transparent',
          outline: 'border-input',
          muted: 'bg-muted/50'
        },
        size: {
          default: 'gap-4 p-4',
          sm: 'gap-2.5 px-4 py-3'
        }
      },
      defaults: { variant: :default, size: :default }
    )

    attr_reader :variant, :size

    renders_one :header, Ui::Item::HeaderComponent
    renders_one :media, Ui::Item::MediaComponent
    renders_one :title, Ui::Item::TitleComponent
    renders_one :description, Ui::Item::DescriptionComponent
    renders_one :actions, Ui::Item::ActionsComponent
    renders_one :footer, Ui::Item::FooterComponent

    def initialize(variant: :default, size: :default, **html_attributes)
      @variant = variant
      @size = size
      super(**html_attributes)
    end

    def variant_values
      { variant: variant, size: size }
    end
  end
end
