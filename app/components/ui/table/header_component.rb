# frozen_string_literal: true

module Ui
  module Table
    # Rows repeat in call order under the header (rule 3); every row is the
    # same kind of part here, so no polymorphic types are needed at this level.
    class HeaderComponent < Ui::Base
      data_slot 'table-header'

      class_variants(base: '[&_tr]:border-b')

      renders_many :rows, Ui::Table::RowComponent
    end
  end
end
