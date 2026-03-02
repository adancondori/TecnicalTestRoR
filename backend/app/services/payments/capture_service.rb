# frozen_string_literal: true

module Payments
  class CaptureService
    attr_reader :payment_request, :amount

    def initialize(payment_request:, amount: nil)
      @payment_request = payment_request
      @amount = amount || payment_request.amount
    end

    def call
      raise PaymentGateway::InvalidState, "Only AUTHORIZED payments with MANUAL capture can be captured" unless capturable?

      raise PaymentGateway::ValidationError, "Capture amount exceeds authorized amount" if amount > payment_request.amount

      merchant = payment_request.merchant
      payment_request.transition_to!("CAPTURED")
      payment_request.update!(captured_amount: amount)
      WebhookService.deliver!(merchant: merchant, event_type: "payment.captured", payload: payment_request.as_json)
      payment_request.transition_to!("SUCCEEDED")
      WebhookService.deliver!(merchant: merchant, event_type: "payment.succeeded", payload: payment_request.as_json)
      payment_request
    end

    private

    def capturable?
      payment_request.status == "AUTHORIZED" && payment_request.capture_method == "MANUAL"
    end
  end
end
