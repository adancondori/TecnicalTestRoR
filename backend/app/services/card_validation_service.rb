# frozen_string_literal: true

class CardValidationService
  NETWORK_PATTERNS = {
    "VISA" => /\A4\d{12,18}\z/,
    "MASTERCARD" => /\A(5[1-5]\d{14}|2[2-7]\d{14})\z/,
    "AMEX" => /\A3[47]\d{13}\z/,
    "DISCOVER" => /\A(6011|65\d{2}|64[4-9]\d)\d{12}\z/
  }.freeze

  THREE_DS_BINS = {
    "4000000000001091" => { requires_3ds: true, challenge_result: "SUCCESS" },
    "5200000000001096" => { requires_3ds: true, challenge_result: "SUCCESS" },
    "4000000000001109" => { requires_3ds: true, challenge_result: "FAILURE" },
    "4000000000001000" => { requires_3ds: false },
    "5200000000001005" => { requires_3ds: false }
  }.freeze

  attr_reader :card_number, :expiry_month, :expiry_year, :cvv, :cardholder_name, :cardholder_email

  def initialize(card_params)
    @card_number = card_params[:card_number]&.gsub(/\s/, "")
    @expiry_month = card_params[:expiry_month].to_i
    @expiry_year = card_params[:expiry_year].to_i
    @cvv = card_params[:cvv]
    @cardholder_name = card_params[:cardholder_name]
    @cardholder_email = card_params[:cardholder_email]
  end

  def validate!
    validate_card_number!
    validate_expiry!
    validate_cvv!
    validate_cardholder!
    true
  end

  def card_network
    NETWORK_PATTERNS.each do |network, pattern|
      return network if card_number&.match?(pattern)
    end
    "UNKNOWN"
  end

  def card_type
    card_network == "AMEX" ? "CREDIT" : "CREDIT"
  end

  def masked_card_number
    return nil unless card_number && card_number.length >= 4
    "****#{card_number[-4..]}"
  end

  def card_fingerprint
    return nil unless card_number
    Digest::SHA256.hexdigest(card_number)[0..15]
  end

  def requires_3ds?
    three_ds_config[:requires_3ds] == true
  end

  def three_ds_challenge_result
    three_ds_config[:challenge_result]
  end

  private

  def three_ds_config
    THREE_DS_BINS[card_number] || { requires_3ds: false }
  end

  def validate_card_number!
    raise PaymentGateway::ValidationError, "Card number is required" if card_number.blank?
    raise PaymentGateway::ValidationError, "Invalid card number format" unless card_number.match?(/\A\d{13,19}\z/)
    raise PaymentGateway::ValidationError, "Invalid card number (Luhn check failed)" unless luhn_valid?
  end

  def validate_expiry!
    raise PaymentGateway::ValidationError, "Expiry month is required" if expiry_month.zero?
    raise PaymentGateway::ValidationError, "Expiry year is required" if expiry_year.zero?
    raise PaymentGateway::ValidationError, "Invalid expiry month" unless (1..12).include?(expiry_month)

    expiry_date = Date.new(expiry_year, expiry_month, -1)
    raise PaymentGateway::ValidationError, "Card has expired" if expiry_date < Date.current
  end

  def validate_cvv!
    raise PaymentGateway::ValidationError, "CVV is required" if cvv.blank?
    expected_length = card_network == "AMEX" ? 4 : 3
    raise PaymentGateway::ValidationError, "Invalid CVV" unless cvv.match?(/\A\d{#{expected_length}}\z/)
  end

  def validate_cardholder!
    raise PaymentGateway::ValidationError, "Cardholder name is required" if cardholder_name.blank?
  end

  def luhn_valid?
    digits = card_number.chars.map(&:to_i).reverse
    sum = digits.each_with_index.sum do |digit, i|
      if i.odd?
        doubled = digit * 2
        doubled > 9 ? doubled - 9 : doubled
      else
        digit
      end
    end
    (sum % 10).zero?
  end
end
