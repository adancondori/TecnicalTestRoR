# frozen_string_literal: true

require "rails_helper"

RSpec.describe "QR Payments API", type: :request do
  let(:merchant) { create(:merchant) }
  let(:headers) { authenticated_headers(merchant) }

  describe "POST /api/v1/qr_payments/:id/simulate" do
    it "simulates QR payment scan and auto-captures" do
      pm = create(:payment_method, :qr_code, merchant: merchant)
      pr = create(:payment_request, merchant: merchant, payment_method: pm,
        status: "REQUIRES_ACTION", payment_type: "QR_CODE",
        qr_string: "QR-test-123", amount: 20_000)

      post "/api/v1/qr_payments/#{pr.id}/simulate", headers: headers
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data["status"]).to eq("SUCCEEDED")
      expect(data["captured_amount"]).to eq(20_000)
    end

    it "returns 409 for non-QR or wrong status" do
      pm = create(:payment_method, merchant: merchant)
      pr = create(:payment_request, merchant: merchant, payment_method: pm,
        status: "PENDING", payment_type: "CARD")

      post "/api/v1/qr_payments/#{pr.id}/simulate", headers: headers
      expect(response).to have_http_status(:conflict)
    end
  end
end
