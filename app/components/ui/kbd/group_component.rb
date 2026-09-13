# frozen_string_literal: true

module Ui
  module Kbd
    # A chord like ⌘K: a sequence of key caps in call order.
    class GroupComponent < Ui::Base
      data_slot 'kbd-group'

      class_variants(base: 'inline-flex items-center gap-1')

      renders_many :keys, Ui::KbdComponent
    end
  end
end
