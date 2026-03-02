# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Basic::ControllerMethods
      include MerchantAuthentication

      rescue_from PaymentGateway::BaseError do |e|
        render json: e.to_h, status: e.status
      end

      rescue_from ActiveRecord::RecordNotFound do |_e|
        error = PaymentGateway::NotFound.new
        render json: error.to_h, status: error.status
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        error = PaymentGateway::ValidationError.new(e.message)
        render json: error.to_h, status: error.status
      end
    end
  end
end
