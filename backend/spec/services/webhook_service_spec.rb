# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhookService do
  let(:merchant) { create(:merchant, callback_url: "https://example.com/webhooks", webhook_secret: "test_secret") }

  describe ".deliver!" do
    context "successful delivery" do
      before do
        stub_request(:post, "https://example.com/webhooks")
          .to_return(status: 200, body: "OK")
      end

      it "creates a webhook event with DELIVERED status" do
        event = described_class.deliver!(
          merchant: merchant,
          event_type: "payment.succeeded",
          payload: { id: "pr-123", amount: 10_000 }
        )

        expect(event).to be_a(WebhookEvent)
        expect(event.status).to eq("DELIVERED")
        expect(event.event_type).to eq("payment.succeeded")
        expect(event.attempts).to eq(1)
        expect(event.response_code).to eq(200)
      end

      it "sends HMAC-SHA256 signature in header" do
        described_class.deliver!(
          merchant: merchant,
          event_type: "payment.succeeded",
          payload: { id: "pr-123" }
        )

        expect(WebMock).to have_requested(:post, "https://example.com/webhooks")
          .with { |req| req.headers["X-Webhook-Signature"].present? }
      end

      it "includes correct headers" do
        described_class.deliver!(
          merchant: merchant,
          event_type: "payment.captured",
          payload: { id: "pr-456" }
        )

        expect(WebMock).to have_requested(:post, "https://example.com/webhooks")
          .with(headers: {
            "Content-Type" => "application/json",
            "X-Webhook-Event" => "payment.captured"
          })
      end

      it "generates valid HMAC signature" do
        described_class.deliver!(
          merchant: merchant,
          event_type: "payment.succeeded",
          payload: { id: "pr-789" }
        )

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

      it "builds correct payload structure" do
        event = described_class.deliver!(
          merchant: merchant,
          event_type: "payment.succeeded",
          payload: { id: "pr-789" }
        )

        expect(event.payload).to include("event" => "payment.succeeded")
        expect(event.payload).to include("data" => { "id" => "pr-789" })
        expect(event.payload).to have_key("created_at")
      end
    end

    context "failed delivery" do
      before do
        stub_request(:post, "https://example.com/webhooks")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "marks as FAILED after retry" do
        event = described_class.deliver!(
          merchant: merchant,
          event_type: "payment.failed",
          payload: { id: "pr-fail" }
        )

        expect(event.status).to eq("FAILED")
        expect(event.attempts).to eq(1)
        expect(event.response_code).to eq(500)
      end
    end

    context "no callback URL" do
      let(:merchant) { create(:merchant, callback_url: nil) }

      it "returns nil without creating an event" do
        result = described_class.deliver!(
          merchant: merchant,
          event_type: "payment.succeeded",
          payload: { id: "pr-123" }
        )

        expect(result).to be_nil
        expect(WebhookEvent.count).to eq(0)
      end
    end

    context "network error" do
      before do
        stub_request(:post, "https://example.com/webhooks")
          .to_raise(Errno::ECONNREFUSED.new("Connection refused"))
      end

      it "marks as FAILED" do
        event = described_class.deliver!(
          merchant: merchant,
          event_type: "payment.succeeded",
          payload: { id: "pr-err" }
        )

        expect(event.status).to eq("FAILED")
        expect(event.attempts).to eq(1)
      end
    end
  end
end
