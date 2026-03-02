# frozen_string_literal: true

module Payments
  class VoidService
    attr_reader :payment_request

    def initialize(payment_request:)
      @payment_request = payment_request
    end

    def call
      unless payment_request.status == "AUTHORIZED"
        raise PaymentGateway::InvalidState, "Can only void AUTHORIZED payments"
      end

      payment_request.transition_to!("VOIDED")
      WebhookService.deliver!(merchant: payment_request.merchant, event_type: "void.succeeded", payload: payment_request.as_json)
      payment_request
    end
  end
end
