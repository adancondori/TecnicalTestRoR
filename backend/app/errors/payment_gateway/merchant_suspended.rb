# frozen_string_literal: true

module PaymentGateway
  class MerchantSuspended < BaseError
    def initialize(message = "Merchant account is suspended")
      super(message, status: 403, error_code: "MERCHANT_SUSPENDED")
    end
  end
end
