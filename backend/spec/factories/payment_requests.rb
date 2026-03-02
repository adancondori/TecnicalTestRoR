# frozen_string_literal: true

FactoryBot.define do
  factory :payment_request do
    id { "pr-#{SecureRandom.uuid}" }
    merchant
    payment_method
    reference_id { "ref-#{SecureRandom.hex(8)}" }
    amount { 10_000 }
    currency { "USD" }
    status { "PENDING" }
    capture_method { "AUTOMATIC" }
    payment_type { "CARD" }
    description { "Test payment" }

    trait :authorized do
      status { "AUTHORIZED" }
    end

    trait :manual_capture do
      capture_method { "MANUAL" }
    end

    trait :captured do
      status { "CAPTURED" }
      captured_amount { 10_000 }
    end

    trait :succeeded do
      status { "SUCCEEDED" }
      captured_amount { 10_000 }
    end

    trait :requires_action do
      status { "REQUIRES_ACTION" }
    end

    trait :ewallet do
      payment_type { "EWALLET" }
      payment_method { association :payment_method, :ewallet }
      channel_code { "OVO" }
    end

    trait :qr_code do
      payment_type { "QR_CODE" }
      payment_method { association :payment_method, :qr_code }
      channel_code { "QRIS" }
      qr_string { "QR-test-#{SecureRandom.hex(8)}" }
    end
  end
end
