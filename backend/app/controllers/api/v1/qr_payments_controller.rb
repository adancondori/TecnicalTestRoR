# frozen_string_literal: true

module Api
  module V1
    class QrPaymentsController < BaseController
      def simulate
        payment_request = current_merchant.payment_requests.find(params[:id])
        result = Payments::QrSimulateService.new(payment_request: payment_request).call

        render json: {
          data: {
            id: result.id,
            status: result.status,
            amount: result.amount,
            captured_amount: result.captured_amount,
            payment_type: result.payment_type
          }
        }
      end
    end
  end
end
