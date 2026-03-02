# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "QR Payments", type: :request do
  let(:merchant) { create(:merchant) }
  let(:Authorization) { ActionController::HttpAuthentication::Basic.encode_credentials(merchant.api_key, merchant.api_secret) }

  path "/api/v1/qr_payments/{id}/simulate" do
    post "Simulate a QR code payment" do
      tags "QR Payments"
      operationId "simulateQrPayment"
      produces "application/json"
      security [basic_auth: []]
      description "Simulates a customer scanning and completing a QR code payment. Test-only endpoint."

      parameter name: :id, in: :path, type: :string, description: "Payment request ID (must be a QR_CODE payment in REQUIRES_ACTION status)"

      response "200", "QR payment simulated" do
        schema type: :object, properties: {
          data: {
            type: :object,
            properties: {
              id: { type: :string },
              status: { type: :string },
              amount: { type: :integer },
              captured_amount: { type: :integer },
              payment_type: { type: :string }
            }
          }
        }

        let(:payment_request) { create(:payment_request, :requires_action, :qr_code, merchant: merchant) }
        let(:id) { payment_request.id }

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data["status"]).to eq("SUCCEEDED")
        end
      end

      response "404", "Payment request not found" do
        schema "$ref" => "#/components/schemas/error"
        let(:id) { "pr-nonexistent" }
        run_test!
      end
    end
  end
end
