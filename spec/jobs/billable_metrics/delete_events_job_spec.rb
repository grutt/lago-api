# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BillableMetrics::DeleteEventsJob, type: :job, transaction: false do
  let(:billable_metric) { create(:billable_metric, :deleted) }
  let(:subscription) { create(:subscription) }
  let(:charge) { create(:standard_charge, plan: subscription.plan, billable_metric:) }

  it 'deletes related events' do
    create(:standard_charge, plan: subscription.plan, billable_metric:)
    not_impacted_event = create(:event, subscription_id: subscription.id)
    event = create(:event, code: billable_metric.code, subscription_id: subscription.id)
    create(:cached_aggregation, charge:)

    freeze_time do
      expect { described_class.perform_now(billable_metric) }
        .to change { event.reload.deleted_at }.from(nil).to(Time.current)
        .and change(CachedAggregation, :count).from(1).to(0)

      expect(not_impacted_event.reload.deleted_at).to be_nil
    end
  end
end
