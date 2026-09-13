# frozen_string_literal: true

require 'test_helper'

module Ui
  class TableComponentTest < ViewComponent::TestCase
    PART_SLOTS = %w[table-caption table-header table-body table-footer table-row table-head table-cell].freeze

    def classes_for(slot)
      page.find("[data-slot='#{slot}']", match: :first)['class'].split
    end

    def render_full_table
      render_inline(Ui::TableComponent.new) do |table|
        table.with_caption { 'A list of invoices' }
        table.with_header { |header| header.with_row { |row| add_header_cells(row) } }
        table.with_body { |body| body.with_row { |row| add_cells(row, 'INV001', 'Paid') } }
        table.with_footer { |footer| footer.with_row { |row| add_cells(row, 'Total', '1') } }
      end
    end

    def add_header_cells(row)
      row.with_head { 'Invoice' }
      row.with_head { 'Status' }
    end

    def add_cells(row, first, second)
      row.with_cell { first }
      row.with_cell { second }
    end

    test 'renders a table inside a scroll container, with the table data-slot and token classes' do
      render_inline(Ui::TableComponent.new) { |table| table.with_body { |body| body.with_row { |row| row.with_cell { 'x' } } } }

      assert_selector "[data-slot='table-container'] > table[data-slot='table']"
      assert_includes classes_for('table'), 'w-full'
      assert_includes classes_for('table'), 'caption-bottom'
    end

    test 'the scroll container overflows horizontally' do
      render_inline(Ui::TableComponent.new) { |table| table.with_body { |body| body.with_row { |row| row.with_cell { 'x' } } } }

      assert_selector "[data-slot='table-container'].overflow-x-auto"
    end

    test 'renders every part with its data-slot' do
      render_full_table

      PART_SLOTS.each { |slot| assert_selector "[data-slot='table'] [data-slot='#{slot}']", minimum: 1 }
    end

    test 'renders caption, header, body and footer in that fixed order regardless of call order' do
      render_inline(Ui::TableComponent.new) do |table|
        table.with_footer { |footer| footer.with_row { |row| row.with_cell { 'Total' } } }
        table.with_body { |body| body.with_row { |row| row.with_cell { 'INV001' } } }
        table.with_caption { 'A list of invoices' }
        table.with_header { |header| header.with_row { |row| row.with_head { 'Invoice' } } }
      end

      order = page.all("table[data-slot='table'] > [data-slot]").map { |node| node['data-slot'] }
      assert_equal %w[table-caption table-header table-body table-footer], order
    end

    test 'rows render in call order under the header, body and footer' do
      render_inline(Ui::TableComponent.new) do |table|
        table.with_body do |body|
          body.with_row { |row| row.with_cell { 'Second' } }
          body.with_row { |row| row.with_cell { 'First' } }
        end
      end

      rows = page.all("[data-slot='table-body'] > [data-slot='table-row']").map { |row| row.text.strip }
      assert_equal %w[Second First], rows
    end

    test 'a row interleaves head and cell parts in call order' do
      render_inline(Ui::TableComponent.new) do |table|
        table.with_body do |body|
          body.with_row do |row|
            row.with_head { 'Row header' }
            row.with_cell { 'Value one' }
            row.with_cell { 'Value two' }
          end
        end
      end

      cells = page.all("[data-slot='table-row'] > [data-slot]")
      assert_equal(%w[table-head table-cell table-cell], cells.map { |node| node['data-slot'] })
      assert_equal ['Row header', 'Value one', 'Value two'], cells.map(&:text)
    end

    test 'omitted parts render no element' do
      render_inline(Ui::TableComponent.new) { |table| table.with_body { |body| body.with_row { |row| row.with_cell { 'Only body' } } } }

      assert_selector "[data-slot='table-body']"
      assert_no_selector "[data-slot='table-caption']"
      assert_no_selector "[data-slot='table-header']"
      assert_no_selector "[data-slot='table-footer']"
    end

    test 'caller class on the root wins over a conflicting default' do
      render_inline(Ui::TableComponent.new(class: 'w-auto')) { |table| table.with_body { |body| body.with_row { |row| row.with_cell { 'x' } } } }

      assert_includes classes_for('table'), 'w-auto'
      assert_not_includes classes_for('table'), 'w-full'
    end

    test 'caller class on a part wins over a conflicting default' do
      render_inline(Ui::TableComponent.new) do |table|
        table.with_caption(class: 'text-foreground') { 'Caption' }
        table.with_body { |body| body.with_row(class: 'border-0') { |row| row.with_cell(class: 'p-4') { 'x' } } }
      end

      assert_includes classes_for('table-caption'), 'text-foreground'
      assert_not_includes classes_for('table-caption'), 'text-muted-foreground'
      assert_includes classes_for('table-row'), 'border-0'
      assert_includes classes_for('table-cell'), 'p-4'
      assert_not_includes classes_for('table-cell'), 'p-2'
    end

    test 'forwards html attributes to the root element' do
      render_inline(Ui::TableComponent.new(id: 'invoices', data: { testid: 'table' })) do |table|
        table.with_body { |body| body.with_row { |row| row.with_cell { 'x' } } }
      end

      assert_selector "table#invoices[data-slot='table'][data-testid='table']"
    end

    test 'forwards html attributes to a part' do
      render_inline(Ui::TableComponent.new) do |table|
        table.with_body do |body|
          body.with_row(id: 'row-1') do |row|
            row.with_cell(data: { testid: 'amount' }) { '$10' }
          end
        end
      end

      assert_selector "tr#row-1[data-slot='table-row']"
      assert_selector "td[data-slot='table-cell'][data-testid='amount']"
    end

    test 'nested parts compose from an erb template' do
      render_in_view_context do
        render(inline: <<~ERB)
          <%= render Ui::TableComponent.new(id: "erb-table") do |table| %>
            <% table.with_caption { "Recent invoices" } %>
            <% table.with_header do |header| %>
              <% header.with_row do |row| %>
                <% row.with_head { "Invoice" } %>
                <% row.with_head { "Status" } %>
              <% end %>
            <% end %>
            <% table.with_body do |body| %>
              <% body.with_row do |row| %>
                <% row.with_cell { "INV001" } %>
                <% row.with_cell { "Paid" } %>
              <% end %>
            <% end %>
          <% end %>
        ERB
      end

      assert_selector "#erb-table > [data-slot='table-caption']", text: 'Recent invoices'
      assert_selector "#erb-table [data-slot='table-header'] [data-slot='table-head']", count: 2
      assert_selector "#erb-table [data-slot='table-body'] [data-slot='table-cell']", text: 'INV001'
      assert_equal 1, page.all("[data-slot='table-caption']").size
    end
  end
end
