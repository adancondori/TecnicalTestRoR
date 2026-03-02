# frozen_string_literal: true

module MerchantAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_merchant!
    attr_reader :current_merchant
  end

  private

  def authenticate_merchant!
    authenticate_with_http_basic do |api_key, api_secret|
      merchant = Merchant.find_by(api_key: api_key)

      raise PaymentGateway::AuthenticationFailed unless merchant
      raise PaymentGateway::AuthenticationFailed unless ActiveSupport::SecurityUtils.secure_compare(merchant.api_secret, api_secret)
      raise PaymentGateway::MerchantSuspended if merchant.suspended?

      @current_merchant = merchant
      return true
    end

    raise PaymentGateway::AuthenticationFailed
  end
end
