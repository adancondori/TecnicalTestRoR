# frozen_string_literal: true

FactoryBot.define do
  factory :three_d_secure_challenge do
    id { "3ds-#{SecureRandom.uuid}" }
    payment_method
    status { "PENDING" }
    challenge_url { "http://localhost:3001/3ds/challenge/#{payment_method.id}" }
    version { "2.0" }
  end
end
