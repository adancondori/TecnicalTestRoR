# frozen_string_literal: true

class EwalletSimulationController < ApplicationController
  layout "external"
  skip_forgery_protection

  def pay
    @payment_request = PaymentRequest.find(params[:id])
    raise PaymentGateway::InvalidState, "Payment is not awaiting action" unless @payment_request.status == "REQUIRES_ACTION"
  end

  def confirm
    @payment_request = PaymentRequest.find(params[:id])
    raise PaymentGateway::InvalidState, "Payment is not awaiting action" unless @payment_request.status == "REQUIRES_ACTION"

    merchant = @payment_request.merchant
    @payment_request.transition_to!("AUTHORIZED")
    WebhookService.deliver!(merchant: merchant, event_type: "payment.authorized", payload: @payment_request.as_json)

    if @payment_request.capture_method == "AUTOMATIC"
      @payment_request.transition_to!("CAPTURED")
      @payment_request.update!(captured_amount: @payment_request.amount)
      WebhookService.deliver!(merchant: merchant, event_type: "payment.captured", payload: @payment_request.as_json)
      @payment_request.transition_to!("SUCCEEDED")
      WebhookService.deliver!(merchant: merchant, event_type: "payment.succeeded", payload: @payment_request.as_json)
    end

    render :success
  end
end
