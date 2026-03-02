# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Payment Methods API", type: :request do
  let(:merchant) { create(:merchant) }
  let(:headers) { authenticated_headers(merchant) }

  describe "POST /api/v1/payment_methods" do
    context "with a valid card (no 3DS)" do
      let(:params) do
        {
          type: "CARD",
          card: {
            card_number: "4000000000001000",
            expiry_month: "12",
            expiry_year: (Date.current.year + 2).to_s,
            cvv: "123",
            cardholder_name: "John Doe"
          }
        }
      end

      it "creates a payment method with ACTIVE status" do
        post "/api/v1/payment_methods", params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        data = JSON.parse(response.body)["data"]
        expect(data["status"]).to eq("ACTIVE")
        expect(data["type"]).to eq("CARD")
        expect(data["card"]["masked_card_number"]).to eq("****1000")
        expect(data["card"]["card_network"]).to eq("VISA")
        expect(data["card"]["token_id"]).to start_with("tok-")
        expect(data["actions"]).to be_nil
      end
    end

    context "with a 3DS-required card" do
      let(:params) do
        {
          type: "CARD",
          card: {
            card_number: "4000000000001091",
            expiry_month: "12",
            expiry_year: (Date.current.year + 2).to_s,
            cvv: "123",
            cardholder_name: "John Doe"
          }
        }
      end

      it "creates a payment method with PENDING_AUTHENTICATION and 3DS action" do
        post "/api/v1/payment_methods", params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        data = JSON.parse(response.body)["data"]
        expect(data["status"]).to eq("PENDING_AUTHENTICATION")
        expect(data["actions"]).to be_present
        expect(data["actions"].first["type"]).to eq("AUTH")
        expect(data["actions"].first["url"]).to start_with("http")
        expect(data["actions"].first["url"]).to include("/3ds/challenge/")
      end
    end

    context "with invalid card data" do
      it "returns 422 for missing card number" do
        post "/api/v1/payment_methods",
          params: { type: "CARD", card: { expiry_month: "12", expiry_year: "2027", cvv: "123", cardholder_name: "John" } }.to_json,
          headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns 422 for invalid Luhn" do
        post "/api/v1/payment_methods",
          params: { type: "CARD", card: { card_number: "4000000000001234", expiry_month: "12", expiry_year: "2027", cvv: "123", cardholder_name: "John" } }.to_json,
          headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /api/v1/payment_methods" do
    it "returns merchant's payment methods" do
      create_list(:payment_method, 3, merchant: merchant)
      other_merchant = create(:merchant)
      create(:payment_method, merchant: other_merchant)

      get "/api/v1/payment_methods", headers: headers
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data.length).to eq(3)
    end
  end

  describe "GET /api/v1/payment_methods/:id" do
    it "returns a specific payment method" do
      pm = create(:payment_method, merchant: merchant)
      get "/api/v1/payment_methods/#{pm.id}", headers: headers
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data["id"]).to eq(pm.id)
    end

    it "returns 404 for another merchant's payment method" do
      other = create(:merchant)
      pm = create(:payment_method, merchant: other)
      get "/api/v1/payment_methods/#{pm.id}", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
