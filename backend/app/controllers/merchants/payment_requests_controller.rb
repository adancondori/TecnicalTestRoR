# frozen_string_literal: true

module Merchants
  class PaymentRequestsController < ApplicationController
    before_action :set_merchant
    before_action :set_payment_request

    def show
      @refunds = @payment_request.refunds.order(created_at: :desc)
    end

    def capture
      Payments::CaptureService.new(
        payment_request: @payment_request,
        amount: params[:amount].present? ? params[:amount].to_i : nil
      ).call

      redirect_to merchant_payment_request_path(@merchant, @payment_request), notice: "Payment captured successfully."
    rescue PaymentGateway::InvalidState, PaymentGateway::ValidationError => e
      redirect_to merchant_payment_request_path(@merchant, @payment_request), alert: e.message
    end

    def void
      Payments::VoidService.new(payment_request: @payment_request).call

      redirect_to merchant_payment_request_path(@merchant, @payment_request), notice: "Payment voided successfully."
    rescue PaymentGateway::InvalidState => e
      redirect_to merchant_payment_request_path(@merchant, @payment_request), alert: e.message
    end

    private

    def set_merchant
      @merchant = Merchant.find(params[:merchant_id])
    end

    def set_payment_request
      @payment_request = @merchant.payment_requests.find(params[:id])
    end
  end
end
