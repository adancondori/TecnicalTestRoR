# frozen_string_literal: true

module PaymentGateway
  class BaseError < StandardError
    attr_reader :status, :error_code

    def initialize(message = "Something went wrong", status: 500, error_code: "INTERNAL_ERROR")
      @status = status
      @error_code = error_code
      super(message)
    end

    def to_h
      {
        error: {
          code: error_code,
          message: message
        }
      }
    end
  end
end
