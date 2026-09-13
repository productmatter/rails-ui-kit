# frozen_string_literal: true

module Ui
  # A semantic <table> in a horizontally scrolling container, with a fixed
  # anatomy -- caption, header, body, footer -- in that order whatever order
  # the caller sets them in (Card), since HTML only allows <caption> as a
  # table's first child anyway.
  class TableComponent < Ui::Base
    data_slot 'table'

    class_variants(base: 'w-full caption-bottom text-sm')

    renders_one :caption, Ui::Table::CaptionComponent
    renders_one :header, Ui::Table::HeaderComponent
    renders_one :body, Ui::Table::BodyComponent
    renders_one :footer, Ui::Table::FooterComponent
  end
end
