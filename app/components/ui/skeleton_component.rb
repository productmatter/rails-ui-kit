# frozen_string_literal: true

module Ui
  # A decorative loading placeholder. It's never announced, and its pulse stops
  # under prefers-reduced-motion so it never becomes a source of unwanted motion
  # for a user who has asked for less.
  class SkeletonComponent < Ui::Base
    data_slot 'skeleton'

    class_variants(base: 'animate-pulse rounded-md bg-accent motion-reduce:animate-none')
  end
end
