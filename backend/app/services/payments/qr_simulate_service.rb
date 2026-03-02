# frozen_string_literal: true

module Payments
  class QrSimulateService
    attr_reader :payment_request

    def initialize(payment_request:)
      @payment_request = payment_request
    end

    def call
      unless payment_request.status == "REQUIRES_ACTION" && payment_request.payment_type == "QR_CODE"
        raise PaymentGateway::InvalidState, "Can only simulate QR payments in REQUIRES_ACTION state"
      end

      merchant = payment_request.merchant
      payment_request.transition_to!("AUTHORIZED")
      WebhookService.deliver!(merchant: merchant, event_type: "payment.authorized", payload: payment_request.as_json)

      if payment_request.capture_method == "AUTOMATIC"
        payment_request.transition_to!("CAPTURED")
        payment_request.update!(captured_amount: payment_request.amount)
        WebhookService.deliver!(merchant: merchant, event_type: "payment.captured", payload: payment_request.as_json)
        payment_request.transition_to!("SUCCEEDED")
        WebhookService.deliver!(merchant: merchant, event_type: "payment.succeeded", payload: payment_request.as_json)
      end

      payment_request
    end
  end
end
