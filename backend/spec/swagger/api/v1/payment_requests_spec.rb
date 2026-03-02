# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Payment Requests", type: :request do
  let(:merchant) { create(:merchant) }
  let(:Authorization) { ActionController::HttpAuthentication::Basic.encode_credentials(merchant.api_key, merchant.api_secret) }

  path "/api/v1/payment_requests" do
    post "Create a payment request" do
      tags "Payment Requests"
      operationId "createPaymentRequest"
      consumes "application/json"
      produces "application/json"
      security [basic_auth: []]
      description "Creates a new payment. Supports card (with inline tokenization or existing payment_method_id), e-wallet, and QR code payments."

      parameter name: "X-Request-ID", in: :header, type: :string, required: false,
                description: "Idempotency key to prevent duplicate requests"

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          payment_method_id: { type: :string, description: "Existing payment method ID (alternative to inline card/ewallet/qr_code)" },
          reference_id: { type: :string, description: "Unique merchant reference", example: "order-001" },
          amount: { type: :integer, description: "Amount in cents", example: 10000 },
          currency: { type: :string, example: "USD" },
          capture_method: { type: :string, enum: %w[AUTOMATIC MANUAL] },
          description: { type: :string },
          callback_url: { type: :string, description: "Webhook URL for payment events" },
          success_return_url: { type: :string },
          failure_return_url: { type: :string },
          metadata: { type: :object },
          card: {
            type: :object,
            description: "Inline card tokenization (alternative to payment_method_id)",
            properties: {
              card_number: { type: :string, example: "4000000000001000" },
              expiry_month: { type: :string, example: "12" },
              expiry_year: { type: :string, example: "25" },
              cvv: { type: :string, example: "123" },
              cardholder_name: { type: :string },
              cardholder_email: { type: :string }
            },
            required: %w[card_number expiry_month expiry_year cvv]
          },
          ewallet: {
            type: :object,
            description: "E-wallet payment details",
            properties: {
              channel_code: { type: :string, example: "OVO" }
            },
            required: %w[channel_code]
          },
          qr_code: {
            type: :object,
            description: "QR code payment details",
            properties: {
              channel_code: { type: :string, example: "QRIS" }
            },
            required: %w[channel_code]
          }
        },
        required: %w[reference_id amount currency capture_method]
      }

      response "201", "Payment request created (auto-capture card)" do
        schema type: :object, properties: {
          data: { "$ref" => "#/components/schemas/payment_request" }
        }

        let(:body) do
          {
            reference_id: "order-#{SecureRandom.hex(8)}",
            amount: 50000,
            currency: "USD",
            capture_method: "AUTOMATIC",
            description: "Test payment",
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
          expect(data["id"]).to start_with("pr-")
          expect(data["status"]).to eq("SUCCEEDED")
        end
      end

      response "422", "Validation error" do
        schema "$ref" => "#/components/schemas/error"

        let(:body) do
          { reference_id: "", amount: -1, currency: "USD", capture_method: "AUTOMATIC" }
        end

        run_test!
      end
    end

    get "List payment requests" do
      tags "Payment Requests"
      operationId "listPaymentRequests"
      produces "application/json"
      security [basic_auth: []]
      description "Returns payment requests for the authenticated merchant. Supports filtering by status, reference_id, and date range."

      parameter name: :status, in: :query, type: :string, required: false,
                description: "Filter by status", enum: %w[PENDING REQUIRES_ACTION AUTHORIZED CAPTURED SUCCEEDED FAILED VOIDED REFUNDED]
      parameter name: :reference_id, in: :query, type: :string, required: false,
                description: "Filter by merchant reference ID"
      parameter name: :from_date, in: :query, type: :string, format: "date", required: false,
                description: "Filter payments created on or after this date (ISO8601)"
      parameter name: :to_date, in: :query, type: :string, format: "date", required: false,
                description: "Filter payments created on or before this date (ISO8601)"

      response "200", "List of payment requests" do
        schema type: :object, properties: {
          data: { type: :array, items: { "$ref" => "#/components/schemas/payment_request" } }
        }

        before { create_list(:payment_request, 2, merchant: merchant) }

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data.length).to eq(2)
        end
      end
    end
  end

  path "/api/v1/payment_requests/{id}" do
    get "Get a payment request" do
      tags "Payment Requests"
      operationId "getPaymentRequest"
      produces "application/json"
      security [basic_auth: []]
      description "Returns a single payment request by ID."

      parameter name: :id, in: :path, type: :string, description: "Payment request ID (e.g., pr-abc123)"

      response "200", "Payment request found" do
        schema type: :object, properties: {
          data: { "$ref" => "#/components/schemas/payment_request" }
        }

        let(:payment_request) { create(:payment_request, merchant: merchant) }
        let(:id) { payment_request.id }

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data["id"]).to eq(payment_request.id)
        end
      end

      response "404", "Payment request not found" do
        schema "$ref" => "#/components/schemas/error"
        let(:id) { "pr-nonexistent" }
        run_test!
      end
    end
  end

  path "/api/v1/payment_requests/{id}/capture" do
    post "Capture a payment" do
      tags "Payment Requests"
      operationId "capturePayment"
      consumes "application/json"
      produces "application/json"
      security [basic_auth: []]
      description "Captures a previously authorized payment. Only works for payments with capture_method=MANUAL and status=AUTHORIZED."

      parameter name: :id, in: :path, type: :string, description: "Payment request ID"
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          amount: { type: :integer, description: "Amount to capture in cents (defaults to full authorized amount)", example: 10000 }
        }
      }

      response "200", "Payment captured" do
        schema type: :object, properties: {
          data: { "$ref" => "#/components/schemas/payment_request" }
        }

        let(:payment_request) { create(:payment_request, :authorized, :manual_capture, merchant: merchant) }
        let(:id) { payment_request.id }
        let(:body) { { amount: payment_request.amount } }

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data["status"]).to eq("SUCCEEDED")
        end
      end

      response "404", "Payment request not found" do
        schema "$ref" => "#/components/schemas/error"
        let(:id) { "pr-nonexistent" }
        let(:body) { {} }
        run_test!
      end
    end
  end

  path "/api/v1/payment_requests/{id}/void" do
    post "Void a payment" do
      tags "Payment Requests"
      operationId "voidPayment"
      produces "application/json"
      security [basic_auth: []]
      description "Voids a previously authorized payment. Only works for payments with status=AUTHORIZED."

      parameter name: :id, in: :path, type: :string, description: "Payment request ID"

      response "200", "Payment voided" do
        schema type: :object, properties: {
          data: { "$ref" => "#/components/schemas/payment_request" }
        }

        let(:payment_request) { create(:payment_request, :authorized, :manual_capture, merchant: merchant) }
        let(:id) { payment_request.id }

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data["status"]).to eq("VOIDED")
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
