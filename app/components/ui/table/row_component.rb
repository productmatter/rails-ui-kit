# frozen_string_literal: true

module Ui
  module Table
    # A row's cells interleave head (<th>) and cell (<td>) parts in call order
    # -- a row-header column mixes both kinds in the same row, which is what
    # rule 3's polymorphic renders_many is for.
    class RowComponent < Ui::Base
      data_slot 'table-row'

      class_variants(base: 'border-b transition-colors hover:bg-muted/50')

      renders_many :cells, types: {
        head: { renders: Ui::Table::HeadComponent, as: :head },
        cell: { renders: Ui::Table::CellComponent, as: :cell }
      }
    end
  end
end
