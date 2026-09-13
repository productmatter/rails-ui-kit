# frozen_string_literal: true

module Ui
  # `for:` and every other attribute flow through forwarding. Dimming is CSS-only:
  # peer-disabled tracks a sibling control's native `disabled`, group-data-disabled
  # tracks an ancestor marked `data-disabled="true"` (a fieldset or field group),
  # so pairing with a control never needs a Ruby keyword here.
  class LabelComponent < Ui::Base
    data_slot 'label'

    class_variants(
      base: 'flex items-center gap-2 text-sm leading-none font-medium select-none ' \
            'group-data-[disabled=true]:pointer-events-none group-data-[disabled=true]:opacity-50 ' \
            'peer-disabled:pointer-events-none peer-disabled:opacity-50'
    )
  end
end
