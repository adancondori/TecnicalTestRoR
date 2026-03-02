# frozen_string_literal: true

class WebhookService
  attr_reader :merchant, :event_type, :payload

  def initialize(merchant:, event_type:, payload:)
    @merchant = merchant
    @event_type = event_type
    @payload = payload
  end

  def self.deliver!(merchant:, event_type:, payload:)
    new(merchant: merchant, event_type: event_type, payload: payload).deliver!
  end

  def deliver!
    return unless merchant.callback_url.present?

    webhook_event = merchant.webhook_events.create!(
      event_type: event_type,
      payload: full_payload,
      status: "PENDING"
    )

    WebhookDeliveryJob.perform_now(webhook_event.id)
    webhook_event.reload
  end

  private

  def full_payload
    {
      event: event_type,
      data: payload,
      created_at: Time.current.iso8601
    }
  end
end
