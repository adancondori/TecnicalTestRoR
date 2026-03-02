# frozen_string_literal: true

module Api
  module V1
    class PaymentMethodsController < BaseController
      include Idempotent

      def index
        payment_methods = current_merchant.payment_methods.order(created_at: :desc)
        render json: { data: payment_methods.map { |pm| serialize_payment_method(pm) } }
      end

      def show
        payment_method = current_merchant.payment_methods.find(params[:id])
        render json: { data: serialize_payment_method(payment_method) }
      end

      def create
        check_idempotency!(PaymentMethod)

        result = TokenizationService.new(
          merchant: current_merchant,
          params: payment_method_params,
          base_url: request.base_url
        ).call

        save_request_id!(result[:payment_method])
        render json: { data: serialize_payment_method(result[:payment_method], actions: result[:actions]) }, status: :created
      end

      private

      def payment_method_params
        params.permit(:type, :reusability, card: [:card_number, :expiry_month, :expiry_year, :cvv, :cardholder_name, :cardholder_email])
      end

      def serialize_payment_method(pm, actions: nil)
        data = {
          id: pm.id,
          type: pm.type_name,
          status: pm.status,
          reusability: pm.reusability,
          created_at: pm.created_at&.iso8601,
          updated_at: pm.updated_at&.iso8601,
          metadata: pm.metadata
        }

        if pm.type_name == "CARD"
          data[:card] = {
            token_id: pm.token_id,
            masked_card_number: pm.masked_card_number,
            card_network: pm.card_network,
            card_type: pm.card_type,
            expiry_month: pm.expiry_month,
            expiry_year: pm.expiry_year,
            cardholder_name: pm.cardholder_name,
            fingerprint: pm.card_fingerprint
          }
        end

        data[:actions] = actions if actions.present?
        data
      end
    end
  end
end
