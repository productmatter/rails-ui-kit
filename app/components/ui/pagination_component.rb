# frozen_string_literal: true

module Ui
  # `nav` › `ul` of page links, in call order whatever order the caller sets
  # them in (Card). Numbered links and the previous/next controls are the
  # same `link` part -- only `active:` and the accessible name differ --
  # interleaved with `ellipsis` markers where pages are skipped (rule 3). No
  # `pagy` adapter: wiring this to a paginator is host code.
  class PaginationComponent < Ui::Base
    data_slot 'pagination'

    renders_many :items, types: {
      link: { renders: Ui::Pagination::LinkComponent, as: :link },
      ellipsis: { renders: Ui::Pagination::EllipsisComponent, as: :ellipsis }
    }
  end
end
