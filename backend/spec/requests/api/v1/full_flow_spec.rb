# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Full Payment Flows", type: :request do
  let(:merchant) { create(:merchant) }
  let(:headers) { authenticated_headers(merchant) }

  describe "Scenario 1: Card tokenization -> payment -> refund" do
    it "completes end-to-end" do
      # Step 1: Tokenize card (no 3DS)
      post "/api/v1/payment_methods",
        params: {
          type: "CARD",
          card: { card_number: "4000000000001000", expiry_month: "12", expiry_year: (Date.current.year + 2).to_s, cvv: "123", cardholder_name: "John" }
        }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)
      pm_data = JSON.parse(response.body)["data"]
      expect(pm_data["status"]).to eq("ACTIVE")
      payment_method_id = pm_data["id"]

      # Step 2: Create payment using token
      post "/api/v1/payment_requests",
        params: {
          payment_method_id: payment_method_id,
          reference_id: "flow1-order-001",
          amount: 50_000,
          currency: "USD"
        }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)
      pr_data = JSON.parse(response.body)["data"]
      expect(pr_data["status"]).to eq("SUCCEEDED")
      payment_request_id = pr_data["id"]

      # Step 3: Partial refund
      post "/api/v1/payment_requests/#{payment_request_id}/refunds",
        params: { amount: 20_000, reason: "Partial return" }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)
      refund_data = JSON.parse(response.body)["data"]
      expect(refund_data["amount"]).to eq(20_000)

      # Step 4: Check payment request status (still SUCCEEDED, partial refund)
      get "/api/v1/payment_requests/#{payment_request_id}", headers: headers
      pr_data = JSON.parse(response.body)["data"]
      expect(pr_data["refunded_amount"]).to eq(20_000)
      expect(pr_data["status"]).to eq("SUCCEEDED")

      # Step 5: Full remaining refund
      post "/api/v1/payment_requests/#{payment_request_id}/refunds",
        params: { amount: 30_000, reason: "Full return" }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)

      get "/api/v1/payment_requests/#{payment_request_id}", headers: headers
      pr_data = JSON.parse(response.body)["data"]
      expect(pr_data["status"]).to eq("REFUNDED")
      expect(pr_data["refunded_amount"]).to eq(50_000)
    end
  end

  describe "Scenario 2: Card with 3DS -> payment (challenge flow)" do
    it "creates payment requiring 3DS then completes after OTP" do
      # Step 1: Create payment with 3DS card
      post "/api/v1/payment_requests",
        params: {
          reference_id: "flow2-order-001",
          amount: 30_000,
          currency: "USD",
          card: { card_number: "4000000000001091", expiry_month: "12", expiry_year: (Date.current.year + 2).to_s, cvv: "123", cardholder_name: "Jane" }
        }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)
      pr_data = JSON.parse(response.body)["data"]
      expect(pr_data["status"]).to eq("REQUIRES_ACTION")
      challenge_url = pr_data["actions"].first["url"]
      payment_method_id = pr_data["payment_method_id"]

      # Step 2: Visit 3DS challenge page
      get challenge_url
      expect(response).to have_http_status(:ok)

      # Step 3: Submit correct OTP
      post challenge_url.gsub("challenge", "challenge") + "/verify", params: { otp: "1234" }
      expect(response).to have_http_status(:ok)

      # Step 4: Verify payment is now SUCCEEDED
      get "/api/v1/payment_requests/#{pr_data['id']}", headers: headers
      pr_data = JSON.parse(response.body)["data"]
      expect(pr_data["status"]).to eq("SUCCEEDED")
    end
  end

  describe "Scenario 3: Manual capture -> capture -> void attempt fails" do
    it "captures then rejects void" do
      pm = create(:payment_method, merchant: merchant)

      # Step 1: Create manual-capture payment
      post "/api/v1/payment_requests",
        params: {
          payment_method_id: pm.id,
          reference_id: "flow3-order-001",
          amount: 75_000,
          currency: "USD",
          capture_method: "MANUAL"
        }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)
      pr_data = JSON.parse(response.body)["data"]
      expect(pr_data["status"]).to eq("AUTHORIZED")
      pr_id = pr_data["id"]

      # Step 2: Capture
      post "/api/v1/payment_requests/#{pr_id}/capture",
        params: { amount: 75_000 }.to_json,
        headers: headers

      expect(response).to have_http_status(:ok)
      pr_data = JSON.parse(response.body)["data"]
      expect(pr_data["status"]).to eq("SUCCEEDED")

      # Step 3: Void fails (already captured)
      post "/api/v1/payment_requests/#{pr_id}/void", headers: headers
      expect(response).to have_http_status(:conflict)
    end
  end

  describe "Scenario 4: Manual capture -> void" do
    it "voids an authorized payment" do
      pm = create(:payment_method, merchant: merchant)

      post "/api/v1/payment_requests",
        params: {
          payment_method_id: pm.id,
          reference_id: "flow4-order-001",
          amount: 25_000,
          currency: "USD",
          capture_method: "MANUAL"
        }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)
      pr_id = JSON.parse(response.body)["data"]["id"]

      post "/api/v1/payment_requests/#{pr_id}/void", headers: headers
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data["status"]).to eq("VOIDED")
    end
  end

  describe "Scenario 5: eWallet payment flow" do
    it "creates eWallet -> simulates confirm -> succeeds" do
      # Step 1: Create eWallet payment
      post "/api/v1/payment_requests",
        params: {
          reference_id: "flow5-order-001",
          amount: 15_000,
          currency: "USD",
          ewallet: { channel_code: "OVO" }
        }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)
      pr_data = JSON.parse(response.body)["data"]
      expect(pr_data["status"]).to eq("REQUIRES_ACTION")
      ewallet_url = pr_data["ewallet_url"]
      pr_id = pr_data["id"]

      # Step 2: Visit eWallet page
      get ewallet_url
      expect(response).to have_http_status(:ok)

      # Step 3: Confirm payment
      post ewallet_url.gsub("/pay/", "/pay/") + "/confirm"
      expect(response).to have_http_status(:ok)

      # Step 4: Verify SUCCEEDED
      get "/api/v1/payment_requests/#{pr_id}", headers: headers
      pr_data = JSON.parse(response.body)["data"]
      expect(pr_data["status"]).to eq("SUCCEEDED")
    end
  end

  describe "Scenario 6: QR payment flow" do
    it "creates QR -> simulates scan -> succeeds" do
      # Step 1: Create QR payment
      post "/api/v1/payment_requests",
        params: {
          reference_id: "flow6-order-001",
          amount: 20_000,
          currency: "USD",
          qr_code: { channel_code: "QRIS" }
        }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)
      pr_data = JSON.parse(response.body)["data"]
      expect(pr_data["status"]).to eq("REQUIRES_ACTION")
      expect(pr_data["qr_string"]).to start_with("QR-")
      pr_id = pr_data["id"]

      # Step 2: Simulate QR scan
      post "/api/v1/qr_payments/#{pr_id}/simulate", headers: headers
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data["status"]).to eq("SUCCEEDED")
    end
  end

  describe "Scenario 7: Tokenization with 3DS (no payment)" do
    it "tokenizes card requiring 3DS, verifies OTP, sends auth webhook" do
      # Step 1: Tokenize 3DS card (standalone, no payment)
      post "/api/v1/payment_methods",
        params: {
          type: "CARD",
          card: { card_number: "4000000000001091", expiry_month: "12", expiry_year: (Date.current.year + 2).to_s, cvv: "123", cardholder_name: "Alice" }
        }.to_json,
        headers: headers

      expect(response).to have_http_status(:created)
      pm_data = JSON.parse(response.body)["data"]
      expect(pm_data["status"]).to eq("PENDING_AUTHENTICATION")
      expect(pm_data["actions"]).to be_present
      challenge_url = pm_data["actions"].first["url"]
      payment_method_id = pm_data["id"]

      # Step 2: Visit 3DS challenge page
      get challenge_url
      expect(response).to have_http_status(:ok)

      # Step 3: Submit correct OTP
      post "#{challenge_url}/verify", params: { otp: "1234" }
      expect(response).to have_http_status(:ok)

      # Step 4: Verify payment method is now ACTIVE
      get "/api/v1/payment_methods/#{payment_method_id}", headers: headers
      pm_data = JSON.parse(response.body)["data"]
      expect(pm_data["status"]).to eq("ACTIVE")

      # Step 5: Verify auth webhook was sent
      webhook_events = merchant.webhook_events.where(event_type: "payment_method.auth_completed")
      expect(webhook_events.count).to eq(1)
    end
  end

  describe "Scenario 8: Idempotency" do
    it "returns 409 on duplicate X-Request-ID" do
      request_id = SecureRandom.uuid

      post "/api/v1/payment_methods",
        params: {
          type: "CARD",
          card: { card_number: "4000000000001000", expiry_month: "12", expiry_year: (Date.current.year + 2).to_s, cvv: "123", cardholder_name: "John" }
        }.to_json,
        headers: headers.merge("X-Request-ID" => request_id)

      expect(response).to have_http_status(:created)

      # Retry with same X-Request-ID
      post "/api/v1/payment_methods",
        params: {
          type: "CARD",
          card: { card_number: "4000000000001000", expiry_month: "12", expiry_year: (Date.current.year + 2).to_s, cvv: "123", cardholder_name: "John" }
        }.to_json,
        headers: headers.merge("X-Request-ID" => request_id)

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body)["error"]["code"]).to eq("DUPLICATE_ERROR")
    end
  end
end
