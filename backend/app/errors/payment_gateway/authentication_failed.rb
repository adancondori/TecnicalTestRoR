# frozen_string_literal: true

module PaymentGateway
  class AuthenticationFailed < BaseError
    def initialize(message = "Invalid API credentials")
      super(message, status: 401, error_code: "AUTHENTICATION_FAILED")
    end
  end
end
