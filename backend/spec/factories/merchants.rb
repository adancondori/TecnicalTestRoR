# frozen_string_literal: true

FactoryBot.define do
  factory :merchant do
    id { "merch-#{SecureRandom.uuid}" }
    business_name { Faker::Company.name }
    api_key { "pk_test_#{SecureRandom.hex(8)}" }
    api_secret { "sk_test_#{SecureRandom.hex(12)}" }
    webhook_secret { "whsec_#{SecureRandom.hex(8)}" }
    callback_url { Faker::Internet.url }
    status { "ACTIVE" }

    trait :suspended do
      status { "SUSPENDED" }
    end
  end
end
