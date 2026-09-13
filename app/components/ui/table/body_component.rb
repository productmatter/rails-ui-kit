# frozen_string_literal: true

module Ui
  module Table
    class BodyComponent < Ui::Base
      data_slot 'table-body'

      class_variants(base: '[&_tr:last-child]:border-0')

      renders_many :rows, Ui::Table::RowComponent
    end
  end
end
