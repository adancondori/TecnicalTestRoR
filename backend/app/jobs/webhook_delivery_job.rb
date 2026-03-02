# frozen_string_literal: true

require "net/http"
require "openssl"

class WebhookDeliveryJob < ApplicationJob
  queue_as :webhooks

  MAX_RETRIES = 1
  BACKOFF_BASE = 3

  def perform(webhook_event_id)
    webhook_event = WebhookEvent.find(webhook_event_id)
    merchant = webhook_event.merchant

    return unless merchant.callback_url.present?

    attempt_delivery(webhook_event, merchant)
  end

  private

  def attempt_delivery(webhook_event, merchant)
    MAX_RETRIES.times do |attempt|
      webhook_event.update!(
        attempts: attempt + 1,
        last_attempt_at: Time.current
      )

      begin
        response = send_webhook(webhook_event, merchant)
        webhook_event.update!(
          response_code: response.code.to_i,
          response_body: response.body&.truncate(1000)
        )

        if response.code.to_i >= 200 && response.code.to_i < 300
          webhook_event.update!(status: "DELIVERED")
          return
        end
      rescue StandardError => e
        webhook_event.update!(
          response_body: e.message.truncate(1000)
        )
      end

      sleep(BACKOFF_BASE**attempt) if attempt < MAX_RETRIES - 1 && !Rails.env.test?
    end

    webhook_event.update!(status: "FAILED")
  end

  def send_webhook(webhook_event, merchant)
    uri = URI.parse(merchant.callback_url)
    body = webhook_event.payload.to_json
    signature = generate_signature(body, merchant.webhook_secret)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.path.presence || "/")
    request["Content-Type"] = "application/json"
    request["X-Webhook-Signature"] = signature
    request["X-Webhook-Event"] = webhook_event.event_type
    request["X-Webhook-Id"] = webhook_event.id
    request.body = body

    http.request(request)
  end

  def generate_signature(body, secret)
    OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      secret,
      body
    )
  end
end
