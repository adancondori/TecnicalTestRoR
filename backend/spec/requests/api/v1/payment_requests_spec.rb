# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payment Requests API", type: :request do
  let(:merchant) { create(:merchant) }
  let(:headers) { authenticated_headers(merchant) }

  describe "POST /api/v1/payment_requests" do
    context "tokenized card payment" do
      let(:payment_method) { create(:payment_method, merchant: merchant) }

      it "creates a SUCCEEDED payment with auto-capture" do
        params = {
          payment_method_id: payment_method.id,
          reference_id: "order-001",
          amount: 50_000,
          currency: "USD"
        }

        post "/api/v1/payment_requests", params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        data = JSON.parse(response.body)["data"]
        expect(data["status"]).to eq("SUCCEEDED")
        expect(data["captured_amount"]).to eq(50_000)
        expect(data["payment_type"]).to eq("CARD")
      end
    end

    context "direct card payment without 3DS" do
      it "auto-captures and succeeds" do
        params = {
          reference_id: "order-002",
          amount: 25_000,
          currency: "USD",
          card: {
            card_number: "4000000000001000",
            expiry_month: "12",
            expiry_year: (Date.current.year + 2).to_s,
            cvv: "123",
            cardholder_name: "John Doe"
          }
        }

        post "/api/v1/payment_requests", params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        data = JSON.parse(response.body)["data"]
        expect(data["status"]).to eq("SUCCEEDED")
      end
    end

    context "direct card payment with 3DS" do
      it "creates REQUIRES_ACTION with 3DS challenge" do
        params = {
          reference_id: "order-003",
          amount: 30_000,
          currency: "USD",
          card: {
            card_number: "4000000000001091",
            expiry_month: "12",
            expiry_year: (Date.current.year + 2).to_s,
            cvv: "123",
            cardholder_name: "John Doe"
          }
        }

        post "/api/v1/payment_requests", params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        data = JSON.parse(response.body)["data"]
        expect(data["status"]).to eq("REQUIRES_ACTION")
        expect(data["actions"]).to be_present
        expect(data["actions"].first["url"]).to start_with("http")
        expect(data["actions"].first["url"]).to include("/3ds/challenge/")
      end
    end

    context "manual capture card payment" do
      let(:payment_method) { create(:payment_method, merchant: merchant) }

      it "creates AUTHORIZED payment without auto-capture" do
        params = {
          payment_method_id: payment_method.id,
          reference_id: "order-004",
          amount: 75_000,
          currency: "USD",
          capture_method: "MANUAL"
        }

        post "/api/v1/payment_requests", params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        data = JSON.parse(response.body)["data"]
        expect(data["status"]).to eq("AUTHORIZED")
        expect(data["capture_method"]).to eq("MANUAL")
      end
    end

    context "eWallet payment" do
      it "creates REQUIRES_ACTION with redirect URL" do
        params = {
          reference_id: "order-005",
          amount: 15_000,
          currency: "USD",
          ewallet: { channel_code: "OVO" }
        }

        post "/api/v1/payment_requests", params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        data = JSON.parse(response.body)["data"]
        expect(data["status"]).to eq("REQUIRES_ACTION")
        expect(data["actions"].first["type"]).to eq("REDIRECT")
        expect(data["ewallet_url"]).to start_with("http")
        expect(data["ewallet_url"]).to include("/ewallet/pay/")
      end
    end

    context "QR code payment" do
      it "creates REQUIRES_ACTION with QR string" do
        params = {
          reference_id: "order-006",
          amount: 20_000,
          currency: "USD",
          qr_code: { channel_code: "QRIS" }
        }

        post "/api/v1/payment_requests", params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        data = JSON.parse(response.body)["data"]
        expect(data["status"]).to eq("REQUIRES_ACTION")
        expect(data["qr_string"]).to start_with("QR-")
        expect(data["actions"].first["type"]).to eq("QR_CODE")
      end
    end

    context "duplicate reference_id" do
      it "returns 422" do
        create(:payment_request, merchant: merchant, reference_id: "dup-001")
        params = {
          payment_method_id: create(:payment_method, merchant: merchant).id,
          reference_id: "dup-001",
          amount: 10_000,
          currency: "USD"
        }

        post "/api/v1/payment_requests", params: params.to_json, headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/v1/payment_requests/:id/capture" do
    it "captures a manually authorized payment" do
      pm = create(:payment_method, merchant: merchant)
      pr = create(:payment_request, merchant: merchant, payment_method: pm, status: "AUTHORIZED", capture_method: "MANUAL", amount: 50_000)

      post "/api/v1/payment_requests/#{pr.id}/capture", params: { amount: 50_000 }.to_json, headers: headers
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data["status"]).to eq("SUCCEEDED")
      expect(data["captured_amount"]).to eq(50_000)
    end
  end

  describe "GET /api/v1/payment_requests" do
    it "returns merchant's payment requests" do
      create_list(:payment_request, 3, merchant: merchant, payment_method: create(:payment_method, merchant: merchant))

      get "/api/v1/payment_requests", headers: headers
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data.length).to eq(3)
    end
  end

  describe "GET /api/v1/payment_requests/:id" do
    it "returns a specific payment request" do
      pm = create(:payment_method, merchant: merchant)
      pr = create(:payment_request, merchant: merchant, payment_method: pm)

      get "/api/v1/payment_requests/#{pr.id}", headers: headers
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data["id"]).to eq(pr.id)
    end
  end
end
