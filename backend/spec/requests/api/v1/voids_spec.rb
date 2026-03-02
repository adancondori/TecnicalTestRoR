# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Voids API", type: :request do
  let(:merchant) { create(:merchant) }
  let(:headers) { authenticated_headers(merchant) }
  let(:payment_method) { create(:payment_method, merchant: merchant) }

  describe "POST /api/v1/payment_requests/:id/void" do
    it "voids an AUTHORIZED payment" do
      pr = create(:payment_request, merchant: merchant, payment_method: payment_method,
        status: "AUTHORIZED", capture_method: "MANUAL")

      post "/api/v1/payment_requests/#{pr.id}/void", headers: headers
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data["status"]).to eq("VOIDED")
    end

    it "returns 409 for non-AUTHORIZED payment" do
      pr = create(:payment_request, merchant: merchant, payment_method: payment_method,
        status: "SUCCEEDED", captured_amount: 10_000)

      post "/api/v1/payment_requests/#{pr.id}/void", headers: headers
      expect(response).to have_http_status(:conflict)
    end
  end
end
