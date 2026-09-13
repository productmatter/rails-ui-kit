# frozen_string_literal: true

module Ui
  module Empty
    class HeaderComponent < Ui::Base
      data_slot 'empty-header'

      class_variants(base: 'flex max-w-sm flex-col items-center gap-2 text-center')

      renders_one :media, Ui::Empty::MediaComponent
      renders_one :title, Ui::Empty::TitleComponent
      renders_one :description, Ui::Empty::DescriptionComponent
    end
  end
end
