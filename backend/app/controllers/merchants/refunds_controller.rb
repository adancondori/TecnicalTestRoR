# frozen_string_literal: true

module Merchants
  class RefundsController < ApplicationController
    before_action :set_merchant
    before_action :set_payment_request

    def create
      Payments::RefundService.new(
        payment_request: @payment_request,
        merchant: @merchant,
        amount: params[:amount].present? ? params[:amount].to_i : nil,
        reason: params[:reason].presence
      ).call

      redirect_to merchant_payment_request_path(@merchant, @payment_request), notice: "Refund created successfully."
    rescue PaymentGateway::InvalidState, PaymentGateway::ValidationError => e
      redirect_to merchant_payment_request_path(@merchant, @payment_request), alert: e.message
    end

    private

    def set_merchant
      @merchant = Merchant.find(params[:merchant_id])
    end

    def set_payment_request
      @payment_request = @merchant.payment_requests.find(params[:payment_request_id])
    end
  end
end
