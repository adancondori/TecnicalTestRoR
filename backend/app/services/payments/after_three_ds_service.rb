# frozen_string_literal: true

module Payments
  class AfterThreeDsService
    attr_reader :payment_request, :success

    def initialize(payment_request:, success:)
      @payment_request = payment_request
      @success = success
    end

    def call
      merchant = payment_request.merchant

      if success
        payment_request.transition_to!("AUTHORIZED")
        WebhookService.deliver!(merchant: merchant, event_type: "payment.authorized", payload: payment_request.as_json)
        auto_capture if payment_request.capture_method == "AUTOMATIC"
      else
        payment_request.transition_to!("FAILED")
        payment_request.update!(failure_code: "3DS_AUTHENTICATION_FAILED")
        WebhookService.deliver!(merchant: merchant, event_type: "payment.failed", payload: payment_request.as_json)
      end
      payment_request
    end

    private

    def auto_capture
      merchant = payment_request.merchant
      payment_request.transition_to!("CAPTURED")
      payment_request.update!(captured_amount: payment_request.amount)
      WebhookService.deliver!(merchant: merchant, event_type: "payment.captured", payload: payment_request.as_json)
      payment_request.transition_to!("SUCCEEDED")
      WebhookService.deliver!(merchant: merchant, event_type: "payment.succeeded", payload: payment_request.as_json)
    end
  end
end
