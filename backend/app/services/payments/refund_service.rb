# frozen_string_literal: true

module Payments
  class RefundService
    attr_reader :payment_request, :merchant, :amount, :reason, :reference_id

    def initialize(payment_request:, merchant:, amount: nil, reason: nil, reference_id: nil)
      @payment_request = payment_request
      @merchant = merchant
      @amount = amount || payment_request.captured_amount
      @reason = reason
      @reference_id = reference_id
    end

    def call
      validate!

      refund = nil
      ActiveRecord::Base.transaction do
        refund = merchant.refunds.create!(
          payment_request: payment_request,
          amount: amount,
          reason: reason,
          reference_id: reference_id,
          status: "SUCCEEDED"
        )

        new_refunded = payment_request.refunded_amount + amount
        payment_request.update!(refunded_amount: new_refunded)

        if new_refunded >= payment_request.captured_amount
          payment_request.transition_to!("REFUNDED")
        end
      end

      WebhookService.deliver!(merchant: merchant, event_type: "refund.succeeded", payload: refund.as_json)
      refund
    end

    private

    def validate!
      unless %w[SUCCEEDED CAPTURED].include?(payment_request.status)
        raise PaymentGateway::InvalidState, "Can only refund SUCCEEDED or CAPTURED payments"
      end

      max_refundable = payment_request.captured_amount - payment_request.refunded_amount
      if amount > max_refundable
        raise PaymentGateway::ValidationError,
          "Refund amount (#{amount}) exceeds refundable amount (#{max_refundable})"
      end
    end
  end
end
