# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhookDeliveryJob, type: :job do
  let(:merchant) { create(:merchant, callback_url: "https://example.com/webhooks", webhook_secret: "test_secret") }

  let(:webhook_event) do
    merchant.webhook_events.create!(
      event_type: "payment.succeeded",
      payload: { event: "payment.succeeded", data: { id: "pr-123", amount: 10_000 }, created_at: Time.current.iso8601 },
      status: "PENDING"
    )
  end

  describe "#perform" do
    context "successful delivery" do
      before do
        stub_request(:post, "https://example.com/webhooks")
          .to_return(status: 200, body: "OK")
      end

      it "marks the event as DELIVERED" do
        described_class.perform_now(webhook_event.id)

        webhook_event.reload
        expect(webhook_event.status).to eq("DELIVERED")
        expect(webhook_event.attempts).to eq(1)
        expect(webhook_event.response_code).to eq(200)
      end

      it "sends HMAC-SHA256 signature in header" do
        described_class.perform_now(webhook_event.id)

        expect(WebMock).to have_requested(:post, "https://example.com/webhooks")
          .with { |req| req.headers["X-Webhook-Signature"].present? }
      end

      it "includes correct headers" do
        described_class.perform_now(webhook_event.id)

        expect(WebMock).to have_requested(:post, "https://example.com/webhooks")
          .with(headers: {
            "Content-Type" => "application/json",
            "X-Webhook-Event" => "payment.succeeded"
          })
      end

      it "generates valid HMAC signature" do
        described_class.perform_now(webhook_event.id)

        request_body = nil
        request_signature = nil

        expect(WebMock).to have_requested(:post, "https://example.com/webhooks")
          .with { |req|
            request_body = req.body
            request_signature = req.headers["X-Webhook-Signature"]
            true
          }

        expected_sig = OpenSSL::HMAC.hexdigest("sha256", "test_secret", request_body)
        expect(request_signature).to eq(expected_sig)
      end
    end

    context "failed delivery with retries" do
      before do
        stub_request(:post, "https://example.com/webhooks")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "attempts once and marks as FAILED" do
        described_class.perform_now(webhook_event.id)

        webhook_event.reload
        expect(webhook_event.status).to eq("FAILED")
        expect(webhook_event.attempts).to eq(1)
        expect(webhook_event.response_code).to eq(500)
      end
    end

    context "network error" do
      before do
        stub_request(:post, "https://example.com/webhooks")
          .to_raise(Errno::ECONNREFUSED.new("Connection refused"))
      end

      it "retries and marks as FAILED" do
        described_class.perform_now(webhook_event.id)

        webhook_event.reload
        expect(webhook_event.status).to eq("FAILED")
        expect(webhook_event.attempts).to eq(1)
      end
    end

    context "merchant without callback URL" do
      let(:merchant) { create(:merchant, callback_url: nil) }

      it "does not attempt delivery" do
        described_class.perform_now(webhook_event.id)

        webhook_event.reload
        expect(webhook_event.status).to eq("PENDING")
        expect(webhook_event.attempts).to eq(0)
      end
    end
  end
end
