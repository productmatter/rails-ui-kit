# frozen_string_literal: true

module Stress
  # Which server response each replace-while-open sequence renders, and the element whose render
  # token says it arrived (docs/specs/ui-stress-page § Behavior, item 13).
  module StreamTable
    STREAM_NAMES = { status_field: 'status_field', cluster_over_dm: 'cluster', cluster_over_po: 'cluster',
                     modal: 'modal', city_field: 'city_field' }.freeze
    STREAM_TARGETS = { status_field: '#page-status-field', cluster_over_dm: '#page-cluster', cluster_over_po: '#page-cluster',
                       modal: '#stress-modal dialog', city_field: '#modal-city-field' }.freeze

    def stream_name(kind) = STREAM_NAMES.fetch(kind)
    def stream_target(kind) = STREAM_TARGETS.fetch(kind)
  end
end
