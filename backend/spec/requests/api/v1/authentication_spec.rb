# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API Authentication", type: :request do
  let(:merchant) { create(:merchant) }
  let(:suspended_merchant) { create(:merchant, :suspended) }

  describe "valid credentials" do
    it "returns 200 for active merchant" do
      get "/api/v1/payment_methods", headers: authenticated_headers(merchant)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "invalid credentials" do
    it "returns 401 with wrong api_key" do
      headers = json_headers.merge(
        "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("bad_key", "bad_secret")
      )
      get "/api/v1/payment_methods", headers: headers
      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]["code"]).to eq("AUTHENTICATION_FAILED")
    end

    it "returns 401 with wrong api_secret" do
      headers = json_headers.merge(
        "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(merchant.api_key, "wrong_secret")
      )
      get "/api/v1/payment_methods", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with no credentials" do
      get "/api/v1/payment_methods", headers: json_headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "suspended merchant" do
    it "returns 403 for suspended merchant" do
      get "/api/v1/payment_methods", headers: authenticated_headers(suspended_merchant)
      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)["error"]["code"]).to eq("MERCHANT_SUSPENDED")
    end
  end
end
