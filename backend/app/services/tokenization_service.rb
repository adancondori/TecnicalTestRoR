# frozen_string_literal: true

class TokenizationService
  attr_reader :merchant, :params, :base_url

  def initialize(merchant:, params:, base_url: "")
    @merchant = merchant
    @params = params
    @base_url = base_url
  end

  def call
    type = params[:type]&.upcase

    case type
    when "CARD"
      tokenize_card
    when "EWALLET"
      tokenize_ewallet
    when "QR_CODE"
      tokenize_qr
    else
      raise PaymentGateway::ValidationError, "Unsupported payment method type: #{type}"
    end
  end

  private

  def tokenize_card
    card_params = params[:card] || {}
    validator = CardValidationService.new(card_params)
    validator.validate!

    payment_method = merchant.payment_methods.create!(
      type_name: "CARD",
      status: validator.requires_3ds? ? "PENDING_AUTHENTICATION" : "ACTIVE",
      reusability: params[:reusability] || "ONE_TIME_USE",
      token_id: "tok-#{SecureRandom.uuid}",
      card_fingerprint: validator.card_fingerprint,
      masked_card_number: validator.masked_card_number,
      card_network: validator.card_network,
      card_type: validator.card_type,
      expiry_month: validator.expiry_month,
      expiry_year: validator.expiry_year,
      cardholder_name: validator.cardholder_name,
      cardholder_email: validator.cardholder_email,
      metadata: params[:metadata]
    )

    actions = nil
    if validator.requires_3ds?
      challenge_path = "#{base_url}/3ds/challenge/#{payment_method.id}"
      challenge = payment_method.three_d_secure_challenges.create!(
        status: "PENDING",
        challenge_url: challenge_path,
        version: "2.0"
      )
      actions = [{ type: "AUTH", url: challenge.challenge_url, method: "GET" }]
    end

    { payment_method: payment_method, actions: actions }
  end

  def tokenize_ewallet
    payment_method = merchant.payment_methods.create!(
      type_name: "EWALLET",
      status: "ACTIVE",
      reusability: params[:reusability] || "ONE_TIME_USE",
      channel_code: params[:channel_code],
      metadata: params[:metadata]
    )

    { payment_method: payment_method, actions: nil }
  end

  def tokenize_qr
    payment_method = merchant.payment_methods.create!(
      type_name: "QR_CODE",
      status: "ACTIVE",
      reusability: params[:reusability] || "ONE_TIME_USE",
      channel_code: params[:channel_code],
      metadata: params[:metadata]
    )

    { payment_method: payment_method, actions: nil }
  end
end
