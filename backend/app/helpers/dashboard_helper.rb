# frozen_string_literal: true

module DashboardHelper
  STATUS_BADGES = {
    "SUCCEEDED" => "success",
    "FAILED" => "danger",
    "PENDING" => "warning",
    "AUTHORIZED" => "info",
    "REQUIRES_ACTION" => "purple",
    "CAPTURED" => "primary",
    "VOIDED" => "secondary",
    "REFUNDED" => "dark",
    "ACTIVE" => "success",
    "SUSPENDED" => "danger"
  }.freeze

  def status_badge(status)
    color = STATUS_BADGES[status] || "secondary"
    if color == "purple"
      content_tag(:span, status, class: "badge", style: "background-color: #6f42c1; color: white;")
    else
      content_tag(:span, status, class: "badge bg-#{color}")
    end
  end

  def format_amount(amount_cents, currency = "USD")
    return "$0.00" if amount_cents.nil? || amount_cents.zero?

    formatted = number_to_currency(amount_cents / 100.0, unit: currency_symbol(currency))
    "#{formatted} #{currency}"
  end

  def payment_type_label(type)
    case type
    when "CARD"
      content_tag(:span, class: "badge bg-primary") { "Card" }
    when "EWALLET"
      content_tag(:span, class: "badge bg-success") { "E-Wallet" }
    when "QR_CODE"
      content_tag(:span, class: "badge bg-info") { "QR Code" }
    else
      content_tag(:span, class: "badge bg-secondary") { type || "N/A" }
    end
  end

  private

  def currency_symbol(currency)
    case currency
    when "USD" then "$"
    when "EUR" then "\u20AC"
    when "GBP" then "\u00A3"
    else "$"
    end
  end
end
