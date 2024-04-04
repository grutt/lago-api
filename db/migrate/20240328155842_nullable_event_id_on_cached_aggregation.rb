# frozen_string_literal: true

class NullableEventIdOnCachedAggregation < ActiveRecord::Migration[7.0]
  def change
    change_column_null :cached_aggregations, :event_id, true
  end
end
