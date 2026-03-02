# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.to_s + "/swagger"

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Payment Gateway API",
        version: "v1",
        description: "A RESTful payment gateway provider supporting cards, e-wallets, and QR code payments."
      },
      paths: {},
      servers: [
        { url: "http://localhost:3001", description: "Development" }
      ],
      components: {
        securitySchemes: {
          basic_auth: {
            type: :http,
            scheme: :basic,
            description: "HTTP Basic Auth using api_key as username and api_secret as password"
          }
        },
        schemas: {
          error: {
            type: :object,
            properties: {
              error: {
                type: :object,
                properties: {
                  code: { type: :string, example: "VALIDATION_ERROR" },
                  message: { type: :string, example: "Invalid parameters" }
                },
                required: %w[code message]
              }
            },
            required: %w[error]
          },
          card_details: {
            type: :object,
            properties: {
              masked_card_number: { type: :string, example: "****1000" },
              card_network: { type: :string, example: "VISA" },
              card_type: { type: :string, example: "CREDIT" },
              expiry_month: { type: :integer, example: 12 },
              expiry_year: { type: :integer, example: 2028 },
              cardholder_name: { type: :string, example: "John Doe" },
              token_id: { type: :string, example: "tok-abc123" },
              fingerprint: { type: :string, example: "abc123def456" }
            }
          },
          action: {
            type: :object,
            properties: {
              type: { type: :string, example: "AUTH" },
              url: { type: :string, example: "/3ds/challenge/pm-abc123", nullable: true },
              qr_string: { type: :string, nullable: true }
            },
            required: %w[type]
          },
          payment_method: {
            type: :object,
            properties: {
              id: { type: :string, example: "pm-abc123" },
              type: { type: :string, enum: %w[CARD EWALLET QR_CODE] },
              status: { type: :string, enum: %w[ACTIVE PENDING_AUTHENTICATION FAILED EXPIRED] },
              reusability: { type: :string, enum: %w[ONE_TIME_USE MULTIPLE_USE] },
              card: { "$ref" => "#/components/schemas/card_details", nullable: true },
              actions: {
                type: :array,
                items: { "$ref" => "#/components/schemas/action" },
                nullable: true
              },
              metadata: { type: :object, nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id type status reusability]
          },
          payment_request: {
            type: :object,
            properties: {
              id: { type: :string, example: "pr-abc123" },
              reference_id: { type: :string, example: "order-001" },
              amount: { type: :integer, example: 10000 },
              currency: { type: :string, example: "USD" },
              status: { type: :string, enum: %w[PENDING REQUIRES_ACTION AUTHORIZED CAPTURED SUCCEEDED FAILED VOIDED REFUNDED] },
              capture_method: { type: :string, enum: %w[AUTOMATIC MANUAL] },
              payment_type: { type: :string, enum: %w[CARD EWALLET QR_CODE], nullable: true },
              payment_method_id: { type: :string, nullable: true },
              description: { type: :string, nullable: true },
              captured_amount: { type: :integer, nullable: true },
              refunded_amount: { type: :integer, nullable: true },
              failure_code: { type: :string, nullable: true },
              channel_code: { type: :string, nullable: true },
              qr_string: { type: :string, nullable: true },
              ewallet_url: { type: :string, nullable: true },
              actions: {
                type: :array,
                items: { "$ref" => "#/components/schemas/action" },
                nullable: true
              },
              metadata: { type: :object, nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id reference_id amount currency status capture_method]
          },
          refund: {
            type: :object,
            properties: {
              id: { type: :string, example: "rf-abc123" },
              payment_request_id: { type: :string, example: "pr-abc123" },
              amount: { type: :integer, example: 5000 },
              reason: { type: :string, nullable: true },
              reference_id: { type: :string, nullable: true },
              status: { type: :string, enum: %w[PENDING SUCCEEDED FAILED] },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            },
            required: %w[id payment_request_id amount status]
          }
        }
      },
      security: [
        { basic_auth: [] }
      ]
    }
  }

  config.openapi_format = :yaml
  config.rswag_dry_run = false
end
