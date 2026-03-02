# frozen_string_literal: true

module PaymentGateway
  class ValidationError < BaseError
    def initialize(message = "Validation failed")
      super(message, status: 422, error_code: "VALIDATION_ERROR")
    end
  end
end
