# frozen_string_literal: true

FactoryBot.define do
  factory :payment_method do
    id { "pm-#{SecureRandom.uuid}" }
    merchant
    type_name { "CARD" }
    status { "ACTIVE" }
    reusability { "ONE_TIME_USE" }
    token_id { "tok-#{SecureRandom.uuid}" }
    card_fingerprint { SecureRandom.hex(8) }
    masked_card_number { "****1000" }
    card_network { "VISA" }
    card_type { "CREDIT" }
    expiry_month { 12 }
    expiry_year { Date.current.year + 2 }
    cardholder_name { Faker::Name.name }

    trait :pending_authentication do
      status { "PENDING_AUTHENTICATION" }
    end

    trait :ewallet do
      type_name { "EWALLET" }
      token_id { nil }
      card_fingerprint { nil }
      masked_card_number { nil }
      card_network { nil }
      card_type { nil }
      expiry_month { nil }
      expiry_year { nil }
      cardholder_name { nil }
      channel_code { "OVO" }
    end

    trait :qr_code do
      type_name { "QR_CODE" }
      token_id { nil }
      card_fingerprint { nil }
      masked_card_number { nil }
      card_network { nil }
      card_type { nil }
      expiry_month { nil }
      expiry_year { nil }
      cardholder_name { nil }
      channel_code { "QRIS" }
    end
  end
end
