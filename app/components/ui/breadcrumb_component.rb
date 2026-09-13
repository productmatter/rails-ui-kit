# frozen_string_literal: true

module Ui
  # `nav` › `ol` of breadcrumb items, in call order whatever order the caller
  # sets them in (Card). A separator sits between every pair of items
  # automatically -- the caller never renders one itself (rule 3). The nav
  # carries no classes of its own; the list underneath does.
  class BreadcrumbComponent < Ui::Base
    data_slot 'breadcrumb'

    renders_many :items, types: {
      link: { renders: Ui::Breadcrumb::LinkComponent, as: :link },
      page: { renders: Ui::Breadcrumb::PageComponent, as: :page },
      ellipsis: { renders: Ui::Breadcrumb::EllipsisComponent, as: :ellipsis }
    }
  end
end
