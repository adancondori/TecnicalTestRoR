# frozen_string_literal: true

module PaymentGateway
  class NotFound < BaseError
    def initialize(message = "Resource not found")
      super(message, status: 404, error_code: "NOT_FOUND")
    end
  end
end
