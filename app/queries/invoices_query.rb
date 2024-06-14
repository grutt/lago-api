# frozen_string_literal: true

class InvoicesQuery < BaseQuery
  def call(search_term:, page:, limit:, filters: {})
    @search_term = search_term
    @customer_id = filters[:customer_id]

    invoices = base_scope.result.includes(:customer)
    invoices = invoices.where(id: filters[:ids]) if filters[:ids].present?
    invoices = invoices.where(customer_id: filters[:customer_id]) if filters[:customer_id].present?
    invoices = invoices.where(status: filters[:status]) if filters[:status].present?
    invoices = invoices.where(payment_status: filters[:payment_status]) if filters[:payment_status].present?
    invoices = invoices.where.not(payment_dispute_lost_at: nil) if filters[:payment_dispute_lost]
    invoices = invoices.order(issuing_date: :desc, created_at: :desc).page(page).per(limit)

    result.invoices = invoices
    result
  end

  private

  attr_reader :search_term

  def base_scope
    organization.invoices.not_generating.ransack(search_params)
  end

  def search_params
    return nil if search_term.blank?

    terms = {
      m: 'or',
      id_cont: search_term,
      number_cont: search_term
    }
    return terms if @customer_id.present?

    terms.merge(
      customer_name_cont: search_term,
      customer_external_id_cont: search_term,
      customer_email_cont: search_term
    )
  end
end
