# frozen_string_literal: true

module Ui
  # A single key cap. Ui::Kbd::GroupComponent composes several into a chord.
  class KbdComponent < Ui::Base
    data_slot 'kbd'

    class_variants(
      base: 'inline-flex h-5 w-fit min-w-5 items-center justify-center gap-1 rounded-sm border ' \
            'border-border bg-muted px-1 font-mono text-xs font-medium text-muted-foreground select-none'
    )
  end
end
