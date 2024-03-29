# frozen_string_literal: true

class TurnQuantifiedEventsIntoCachedAggregations < ActiveRecord::Migration[7.0]
  class CachedAggregation < ApplicationRecord
  end

  class QuantifiedEvent < ApplicationRecord
  end

  def change
    QuantifiedEvent.find_each do |quantified_event|
      sql = <<~SQL
        SELECT charges.id
        FROM billable_metrics
        JOIN charges ON charges.billable_metric_id = billable_metrics.id
          JOIN plans ON plans.id = charges.plan_id
          JOIN subscriptions ON subscriptions.plan_id = plans.id
        WHERE billable_metrics.id = #{quantified_event.billable_metric_id}
          AND subscriptions.external_id = '#{quantified_event.external_subscription_id}'
      SQL
      # TODO: filter the subscription to take the one that was active at the time of the event

      CachedAggregation.create!(
        organization_id: quantified_event.organization_id,
        external_subscription_id: quantified_event.external_subscription_id,
        charge_id: 'TODO',
        group_id: quantified_event.group_id,
        charge_filter_id: quantified_event.charge_filter_id,
        timestamp: quantified_event.added_at,
        grouped_by: quantified_event.grouped_by,
        current_aggregation: quantified_event.properties['total_aggregated_units'],
      )
    end
  end
end

# result.cached_aggregations << CachedAggregation.find_or_initialize_by(

#   charge_id: charge.id,
# ) do |cache|
#   cache.current_aggregation = aggregation_result.total_aggregated_units
#   cache.save!
# end
