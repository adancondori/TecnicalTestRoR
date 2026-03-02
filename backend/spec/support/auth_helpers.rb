# frozen_string_literal: true

module AuthHelpers
  def auth_headers(merchant)
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials(
      merchant.api_key,
      merchant.api_secret
    )
    { "HTTP_AUTHORIZATION" => credentials }
  end

  def json_headers
    { "Content-Type" => "application/json", "Accept" => "application/json" }
  end

  def authenticated_headers(merchant)
    auth_headers(merchant).merge(json_headers)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
