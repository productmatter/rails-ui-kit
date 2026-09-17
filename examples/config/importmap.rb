# frozen_string_literal: true

pin "application", preload: true
# Served by the stimulus-rails gem, not a CDN: a jsDelivr outage must not take every controller
# on the page down with it (the same reason Floating UI is vendored in the kit).
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/turbo-rails", to: "turbo.js"
