# frozen_string_literal: true

module Ui
  module Table
    class FooterComponent < Ui::Base
      data_slot 'table-footer'

      class_variants(base: 'border-t bg-muted/50 font-medium [&>tr]:last:border-b-0')

      renders_many :rows, Ui::Table::RowComponent
    end
  end
end
