# frozen_string_literal: true

module Api
  module V1
    class PaymentRequestsController < BaseController
      include Idempotent

      def index
        payment_requests = current_merchant.payment_requests.order(created_at: :desc)
        payment_requests = apply_filters(payment_requests)
        render json: { data: payment_requests.map { |pr| serialize_payment_request(pr) } }
      end

      def show
        payment_request = current_merchant.payment_requests.find(params[:id])
        render json: { data: serialize_payment_request(payment_request) }
      end

      def create
        check_idempotency!(PaymentRequest)

        result = Payments::CreateService.new(
          merchant: current_merchant,
          params: payment_request_params,
          base_url: request.base_url
        ).call

        save_request_id!(result[:payment_request])
        render json: { data: serialize_payment_request(result[:payment_request], actions: result[:actions]) }, status: :created
      end

      def capture
        payment_request = current_merchant.payment_requests.find(params[:id])
        result = Payments::CaptureService.new(
          payment_request: payment_request,
          amount: params[:amount]&.to_i
        ).call

        render json: { data: serialize_payment_request(result) }
      end

      def void
        payment_request = current_merchant.payment_requests.find(params[:id])
        result = Payments::VoidService.new(payment_request: payment_request).call
        render json: { data: serialize_payment_request(result) }
      end

      private

      def payment_request_params
        params.permit(
          :payment_method_id, :reference_id, :amount, :currency,
          :capture_method, :description, :callback_url,
          :success_return_url, :failure_return_url,
          card: [:card_number, :expiry_month, :expiry_year, :cvv, :cardholder_name, :cardholder_email],
          ewallet: [:channel_code],
          qr_code: [:channel_code],
          metadata: {}
        )
      end

      def apply_filters(scope)
        scope = scope.where(status: params[:status].upcase) if params[:status].present?
        scope = scope.where(reference_id: params[:reference_id]) if params[:reference_id].present?
        scope = scope.where("created_at >= ?", Time.zone.parse(params[:from_date])) if params[:from_date].present?
        scope = scope.where("created_at <= ?", Time.zone.parse(params[:to_date]).end_of_day) if params[:to_date].present?
        scope
      end

      def serialize_payment_request(pr, actions: nil)
        data = {
          id: pr.id,
          reference_id: pr.reference_id,
          amount: pr.amount,
          currency: pr.currency,
          status: pr.status,
          capture_method: pr.capture_method,
          payment_type: pr.payment_type,
          payment_method_id: pr.payment_method_id,
          description: pr.description,
          captured_amount: pr.captured_amount,
          refunded_amount: pr.refunded_amount,
          failure_code: pr.failure_code,
          channel_code: pr.channel_code,
          created_at: pr.created_at&.iso8601,
          updated_at: pr.updated_at&.iso8601,
          metadata: pr.metadata
        }

        data[:qr_string] = pr.qr_string if pr.qr_string.present?
        data[:ewallet_url] = pr.ewallet_url if pr.ewallet_url.present?
        data[:actions] = actions if actions.present?
        data
      end
    end
  end
end
