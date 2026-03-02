# frozen_string_literal: true

module Payments
  class CreateService
    attr_reader :merchant, :params, :base_url

    def initialize(merchant:, params:, base_url: "")
      @merchant = merchant
      @params = params
      @base_url = base_url
    end

    def call
      payment_type = determine_payment_type
      case payment_type
      when "CARD"
        process_card_payment
      when "EWALLET"
        process_ewallet_payment
      when "QR_CODE"
        process_qr_payment
      else
        raise PaymentGateway::ValidationError, "Unsupported payment type"
      end
    end

    private

    def determine_payment_type
      return "CARD" if params[:payment_method_id].present? || params[:card].present?
      return "EWALLET" if params[:ewallet].present?
      return "QR_CODE" if params[:qr_code].present?
      raise PaymentGateway::ValidationError, "Payment type could not be determined"
    end

    def process_card_payment
      if params[:payment_method_id].present?
        process_tokenized_card
      else
        process_direct_card
      end
    end

    def process_tokenized_card
      payment_method = merchant.payment_methods.find(params[:payment_method_id])
      raise PaymentGateway::ValidationError, "Payment method is not active" unless payment_method.active?

      payment_request = create_payment_request(
        payment_method: payment_method,
        payment_type: "CARD"
      )

      # Tokenized card = frictionless -> AUTHORIZED -> auto-capture
      payment_request.transition_to!("AUTHORIZED")
      WebhookService.deliver!(merchant: merchant, event_type: "payment.authorized", payload: payment_request.as_json)
      auto_capture(payment_request)

      { payment_request: payment_request, actions: nil }
    end

    def process_direct_card
      card_params = params[:card] || {}
      validator = CardValidationService.new(card_params)
      validator.validate!

      # Create inline payment method
      payment_method = merchant.payment_methods.create!(
        type_name: "CARD",
        status: validator.requires_3ds? ? "PENDING_AUTHENTICATION" : "ACTIVE",
        reusability: "ONE_TIME_USE",
        token_id: "tok-#{SecureRandom.uuid}",
        card_fingerprint: validator.card_fingerprint,
        masked_card_number: validator.masked_card_number,
        card_network: validator.card_network,
        card_type: validator.card_type,
        expiry_month: validator.expiry_month,
        expiry_year: validator.expiry_year,
        cardholder_name: validator.cardholder_name,
        cardholder_email: validator.cardholder_email
      )

      payment_request = create_payment_request(
        payment_method: payment_method,
        payment_type: "CARD"
      )

      if validator.requires_3ds?
        payment_request.transition_to!("REQUIRES_ACTION")
        challenge_path = "#{base_url}/3ds/challenge/#{payment_method.id}"
        challenge = payment_method.three_d_secure_challenges.create!(
          status: "PENDING",
          payment_request_id: payment_request.id,
          challenge_url: challenge_path,
          version: "2.0"
        )
        actions = [{ type: "AUTH", url: challenge.challenge_url, method: "GET" }]
        WebhookService.deliver!(merchant: merchant, event_type: "payment.requires_action", payload: payment_request.as_json)
        { payment_request: payment_request, actions: actions }
      else
        payment_request.transition_to!("AUTHORIZED")
        WebhookService.deliver!(merchant: merchant, event_type: "payment.authorized", payload: payment_request.as_json)
        auto_capture(payment_request)
        { payment_request: payment_request, actions: nil }
      end
    end

    def process_ewallet_payment
      ewallet_params = params[:ewallet] || {}
      payment_method = merchant.payment_methods.create!(
        type_name: "EWALLET",
        status: "ACTIVE",
        reusability: "ONE_TIME_USE",
        channel_code: ewallet_params[:channel_code]
      )

      payment_request = create_payment_request(
        payment_method: payment_method,
        payment_type: "EWALLET",
        channel_code: ewallet_params[:channel_code]
      )

      payment_request.transition_to!("REQUIRES_ACTION")
      ewallet_url = "#{base_url}/ewallet/pay/#{payment_request.id}"
      payment_request.update!(ewallet_url: ewallet_url)

      actions = [{ type: "REDIRECT", url: ewallet_url, method: "GET" }]
      WebhookService.deliver!(merchant: merchant, event_type: "payment.requires_action", payload: payment_request.as_json)
      { payment_request: payment_request, actions: actions }
    end

    def process_qr_payment
      qr_params = params[:qr_code] || {}
      payment_method = merchant.payment_methods.create!(
        type_name: "QR_CODE",
        status: "ACTIVE",
        reusability: "ONE_TIME_USE",
        channel_code: qr_params[:channel_code] || "QRIS"
      )

      payment_request = create_payment_request(
        payment_method: payment_method,
        payment_type: "QR_CODE",
        channel_code: qr_params[:channel_code] || "QRIS"
      )

      payment_request.transition_to!("REQUIRES_ACTION")
      qr_string = "QR-#{payment_request.id}-#{SecureRandom.hex(8)}"
      payment_request.update!(qr_string: qr_string)

      actions = [{ type: "QR_CODE", qr_string: qr_string }]
      WebhookService.deliver!(merchant: merchant, event_type: "payment.requires_action", payload: payment_request.as_json)
      { payment_request: payment_request, actions: actions }
    end

    def create_payment_request(payment_method:, payment_type:, channel_code: nil)
      merchant.payment_requests.create!(
        payment_method: payment_method,
        reference_id: params[:reference_id],
        amount: params[:amount],
        currency: params[:currency] || "USD",
        capture_method: params[:capture_method] || "AUTOMATIC",
        description: params[:description],
        callback_url: params[:callback_url],
        success_return_url: params[:success_return_url],
        failure_return_url: params[:failure_return_url],
        payment_type: payment_type,
        channel_code: channel_code,
        metadata: params[:metadata]
      )
    end

    def auto_capture(payment_request)
      return unless payment_request.capture_method == "AUTOMATIC"

      payment_request.transition_to!("CAPTURED")
      payment_request.update!(captured_amount: payment_request.amount)
      WebhookService.deliver!(merchant: merchant, event_type: "payment.captured", payload: payment_request.as_json)
      payment_request.transition_to!("SUCCEEDED")
      WebhookService.deliver!(merchant: merchant, event_type: "payment.succeeded", payload: payment_request.as_json)
    end
  end
end
