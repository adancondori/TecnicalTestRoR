# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "Refunds", type: :request do
  let(:merchant) { create(:merchant) }
  let(:Authorization) { ActionController::HttpAuthentication::Basic.encode_credentials(merchant.api_key, merchant.api_secret) }

  path "/api/v1/payment_requests/{payment_request_id}/refunds" do
    post "Create a refund" do
      tags "Refunds"
      operationId "createRefund"
      consumes "application/json"
      produces "application/json"
      security [basic_auth: []]
      description "Creates a refund for a captured/succeeded payment. Supports full and partial refunds."

      parameter name: :payment_request_id, in: :path, type: :string, description: "Payment request ID to refund"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :integer, description: "Refund amount in cents (defaults to full remaining amount)", example: 5000 },
          reason: { type: :string, description: "Reason for the refund", example: "Customer request" },
          reference_id: { type: :string, description: "Merchant reference for this refund", example: "refund-001" }
        }
      }

      response "201", "Refund created" do
        schema type: :object, properties: {
          data: { "$ref" => "#/components/schemas/refund" }
        }

        let(:payment_request) { create(:payment_request, :succeeded, merchant: merchant) }
        let(:payment_request_id) { payment_request.id }
        let(:body) { { amount: 5000, reason: "Customer request" } }

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data["id"]).to start_with("rf-")
          expect(data["status"]).to eq("SUCCEEDED")
        end
      end

      response "404", "Payment request not found" do
        schema "$ref" => "#/components/schemas/error"
        let(:payment_request_id) { "pr-nonexistent" }
        let(:body) { { amount: 5000 } }
        run_test!
      end
    end
  end

  path "/api/v1/refunds" do
    get "List refunds" do
      tags "Refunds"
      operationId "listRefunds"
      produces "application/json"
      security [basic_auth: []]
      description "Returns all refunds belonging to the authenticated merchant."

      response "200", "List of refunds" do
        schema type: :object, properties: {
          data: { type: :array, items: { "$ref" => "#/components/schemas/refund" } }
        }

        before do
          pr = create(:payment_request, :succeeded, merchant: merchant)
          create_list(:refund, 2, payment_request: pr, merchant: merchant)
        end

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data.length).to eq(2)
        end
      end
    end
  end

  path "/api/v1/refunds/{id}" do
    get "Get a refund" do
      tags "Refunds"
      operationId "getRefund"
      produces "application/json"
      security [basic_auth: []]
      description "Returns a single refund by ID."

      parameter name: :id, in: :path, type: :string, description: "Refund ID (e.g., rf-abc123)"

      response "200", "Refund found" do
        schema type: :object, properties: {
          data: { "$ref" => "#/components/schemas/refund" }
        }

        let(:refund) { create(:refund, merchant: merchant) }
        let(:id) { refund.id }

        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data["id"]).to eq(refund.id)
        end
      end

      response "404", "Refund not found" do
        schema "$ref" => "#/components/schemas/error"
        let(:id) { "rf-nonexistent" }
        run_test!
      end
    end
  end
end
