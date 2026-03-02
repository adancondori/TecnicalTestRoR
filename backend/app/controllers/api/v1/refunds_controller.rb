# frozen_string_literal: true

module Api
  module V1
    class RefundsController < BaseController
      def index
        refunds = current_merchant.refunds.order(created_at: :desc)
        render json: { data: refunds.map { |r| serialize_refund(r) } }
      end

      def show
        refund = current_merchant.refunds.find(params[:id])
        render json: { data: serialize_refund(refund) }
      end

      def create
        payment_request = current_merchant.payment_requests.find(params[:payment_request_id])

        refund = Payments::RefundService.new(
          payment_request: payment_request,
          merchant: current_merchant,
          amount: params[:amount]&.to_i,
          reason: params[:reason],
          reference_id: params[:reference_id]
        ).call

        render json: { data: serialize_refund(refund) }, status: :created
      end

      private

      def serialize_refund(refund)
        {
          id: refund.id,
          payment_request_id: refund.payment_request_id,
          amount: refund.amount,
          reason: refund.reason,
          reference_id: refund.reference_id,
          status: refund.status,
          created_at: refund.created_at&.iso8601,
          updated_at: refund.updated_at&.iso8601
        }
      end
    end
  end
end
