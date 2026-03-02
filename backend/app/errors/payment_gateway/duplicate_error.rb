# frozen_string_literal: true

module PaymentGateway
  class DuplicateError < BaseError
    def initialize(message = "Duplicate resource")
      super(message, status: 409, error_code: "DUPLICATE_ERROR")
    end
  end
end
