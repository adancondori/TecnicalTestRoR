# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Refunds API", type: :request do
  let(:merchant) { create(:merchant) }
  let(:headers) { authenticated_headers(merchant) }
  let(:payment_method) { create(:payment_method, merchant: merchant) }

  describe "POST /api/v1/payment_requests/:id/refunds" do
    context "full refund" do
      it "refunds the full captured amount" do
        pr = create(:payment_request, merchant: merchant, payment_method: payment_method,
          status: "SUCCEEDED", captured_amount: 10_000, amount: 10_000)

        post "/api/v1/payment_requests/#{pr.id}/refunds",
          params: { amount: 10_000, reason: "Customer request" }.to_json,
          headers: headers

        expect(response).to have_http_status(:created)

        data = JSON.parse(response.body)["data"]
        expect(data["amount"]).to eq(10_000)
        expect(data["status"]).to eq("SUCCEEDED")

        pr.reload
        expect(pr.status).to eq("REFUNDED")
        expect(pr.refunded_amount).to eq(10_000)
      end
    end

    context "partial refund" do
      it "refunds part of the captured amount" do
        pr = create(:payment_request, merchant: merchant, payment_method: payment_method,
          status: "SUCCEEDED", captured_amount: 10_000, amount: 10_000)

        post "/api/v1/payment_requests/#{pr.id}/refunds",
          params: { amount: 3_000, reason: "Partial" }.to_json,
          headers: headers

        expect(response).to have_http_status(:created)

        pr.reload
        expect(pr.status).to eq("SUCCEEDED") # Not fully refunded yet
        expect(pr.refunded_amount).to eq(3_000)
      end
    end

    context "exceeds refundable amount" do
      it "returns 422" do
        pr = create(:payment_request, merchant: merchant, payment_method: payment_method,
          status: "SUCCEEDED", captured_amount: 10_000, amount: 10_000, refunded_amount: 8_000)

        post "/api/v1/payment_requests/#{pr.id}/refunds",
          params: { amount: 5_000 }.to_json,
          headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "wrong status" do
      it "returns 409 for PENDING payment" do
        pr = create(:payment_request, merchant: merchant, payment_method: payment_method, status: "PENDING")

        post "/api/v1/payment_requests/#{pr.id}/refunds",
          params: { amount: 5_000 }.to_json,
          headers: headers

        expect(response).to have_http_status(:conflict)
      end
    end
  end

  describe "GET /api/v1/refunds" do
    it "returns merchant's refunds" do
      pr = create(:payment_request, merchant: merchant, payment_method: payment_method, status: "SUCCEEDED", captured_amount: 10_000)
      create(:refund, merchant: merchant, payment_request: pr)
      create(:refund, merchant: merchant, payment_request: pr)

      get "/api/v1/refunds", headers: headers
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data.length).to eq(2)
    end
  end
end
