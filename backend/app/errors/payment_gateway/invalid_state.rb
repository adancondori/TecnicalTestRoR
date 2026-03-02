# frozen_string_literal: true

module PaymentGateway
  class InvalidState < BaseError
    def initialize(message = "Invalid state transition")
      super(message, status: 409, error_code: "INVALID_STATE")
    end
  end
end
