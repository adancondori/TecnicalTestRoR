# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Payment Methods", type: :request do
  let(:merchant) { create(:merchant) }
  let(:Authorization) { ActionController::HttpAuthentication::Basic.encode_credentials(merchant.api_key, merchant.api_secret) }

  path "/api/v1/payment_methods" do
    post "Tokenize a payment method" do
      tags "Payment Methods"
      operationId "createPaymentMethod"
      consumes "application/json"
      produces "application/json"
      security [basic_auth: []]
      description "Creates a new payment method by tokenizing card details, e-wallet, or QR code."

      parameter name: "X-Request-ID", in: :header, type: :string, required: false,
                description: "Idempotency key to prevent duplicate requests"

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          type: { type: :string, enum: %w[CARD EWALLET QR_CODE], description: "Payment method type" },
          reusability: { type: :string, enum: %w[ONE_TIME_USE MULTIPLE_USE] },
          card: {
            type: :object,
            properties: {
              card_number: { type: :string, example: "4000000000001000" },
              expiry_month: { type: :string, example: "12" },
              expiry_year: { type: :string, example: "25" },
              cvv: { type: :string, example: "123" },
              cardholder_name: { type: :string, example: "John Doe" },
              cardholder_email: { type: :string, example: "john@example.com" }
            },
            required: %w[card_number expiry_month expiry_year cvv]
          }
        },
        required: %w[type reusability]
      }

      response "201", "Payment method created" do
        schema type: :object, properties: {
          data: { "$ref" => "#/components/schemas/payment_method" }
        }

        let(:body) do
          {
            type: "CARD",
            reusability: "ONE_TIME_USE",
            card: {
              card_number: "4000000000001000",
              expiry_month: "12",
              expiry_year: (Date.current.year + 2).to_s,
              cvv: "123",
              cardholder_name: "John Doe"
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data["id"]).to start_with("pm-")
          expect(data["status"]).to eq("ACTIVE")
        end
      end

      response "401", "Unauthorized" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { ActionController::HttpAuthentication::Basic.encode_credentials("invalid_key", "invalid_secret") }
        let(:body) { { type: "CARD", reusability: "ONE_TIME_USE", card: { card_number: "4000000000001000", expiry_month: "12", expiry_year: (Date.current.year + 2).to_s, cvv: "123" } } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data["error"]["code"]).to eq("AUTHENTICATION_FAILED")
        end
      end

      response "422", "Validation error" do
        schema "$ref" => "#/components/schemas/error"

        let(:body) { { type: "CARD", reusability: "ONE_TIME_USE", card: { card_number: "4000000000001234", expiry_month: "12", expiry_year: "25", cvv: "123" } } }

        run_test!
      end
    end

    get "List payment methods" do
      tags "Payment Methods"
      operationId "listPaymentMethods"
      produces "application/json"
      security [basic_auth: []]
      description "Returns all payment methods belonging to the authenticated merchant."

      response "200", "List of payment methods" do
        schema type: :object, properties: {
          data: { type: :array, items: { "$ref" => "#/components/schemas/payment_method" } }
        }

        before { create_list(:payment_method, 2, merchant: merchant) }

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data.length).to eq(2)
        end
      end
    end
  end

  path "/api/v1/payment_methods/{id}" do
    get "Get a payment method" do
      tags "Payment Methods"
      operationId "getPaymentMethod"
      produces "application/json"
      security [basic_auth: []]
      description "Returns a single payment method by ID."

      parameter name: :id, in: :path, type: :string, description: "Payment method ID (e.g., pm-abc123)"

      response "200", "Payment method found" do
        schema type: :object, properties: {
          data: { "$ref" => "#/components/schemas/payment_method" }
        }

        let(:payment_method) { create(:payment_method, merchant: merchant) }
        let(:id) { payment_method.id }

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data["id"]).to eq(payment_method.id)
        end
      end

      response "404", "Payment method not found" do
        schema "$ref" => "#/components/schemas/error"
        let(:id) { "pm-nonexistent" }
        run_test!
      end
    end
  end
end
