# frozen_string_literal: true

FactoryBot.define do
  factory :refund do
    id { "rf-#{SecureRandom.uuid}" }
    payment_request { association :payment_request, :succeeded }
    merchant
    amount { 5_000 }
    reason { "Customer request" }
    reference_id { "refund-#{SecureRandom.hex(6)}" }
    status { "SUCCEEDED" }
  end
end
