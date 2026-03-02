# frozen_string_literal: true

module ThreeDSecure
  class VerificationService
    attr_reader :challenge, :success

    def initialize(challenge:, success:)
      @challenge = challenge
      @success = success
    end

    def call
      success ? handle_success : handle_failure
    end

    private

    def handle_success
      challenge.update!(status: "COMPLETED", eci_code: "05")
      payment_method.update!(status: "ACTIVE")

      WebhookService.deliver!(
        merchant: merchant,
        event_type: "payment_method.auth_completed",
        payload: payment_method.as_json
      )

      delegate_to_payment_flow if challenge.payment_request_id.present?
    end

    def handle_failure
      challenge.update!(status: "FAILED")
      payment_method.update!(status: "FAILED")

      WebhookService.deliver!(
        merchant: merchant,
        event_type: "payment_method.auth_failed",
        payload: payment_method.as_json
      )

      delegate_to_payment_flow if challenge.payment_request_id.present?
    end

    def delegate_to_payment_flow
      payment_request = PaymentRequest.find(challenge.payment_request_id)
      Payments::AfterThreeDsService.new(payment_request: payment_request, success: success).call
    end

    def payment_method
      challenge.payment_method
    end

    def merchant
      payment_method.merchant
    end
  end
end
