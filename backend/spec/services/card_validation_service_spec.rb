# frozen_string_literal: true

require "rails_helper"

RSpec.describe CardValidationService do
  describe "#validate!" do
    it "passes for a valid VISA card" do
      service = described_class.new(
        card_number: "4000000000001000",
        expiry_month: "12",
        expiry_year: (Date.current.year + 2).to_s,
        cvv: "123",
        cardholder_name: "John Doe"
      )
      expect(service.validate!).to be true
    end

    it "passes for a valid Mastercard" do
      service = described_class.new(
        card_number: "5200000000001005",
        expiry_month: "06",
        expiry_year: (Date.current.year + 1).to_s,
        cvv: "456",
        cardholder_name: "Jane Doe"
      )
      expect(service.validate!).to be true
    end

    it "raises on missing card number" do
      service = described_class.new(
        card_number: nil,
        expiry_month: "12",
        expiry_year: "2027",
        cvv: "123",
        cardholder_name: "John"
      )
      expect { service.validate! }.to raise_error(PaymentGateway::ValidationError, /Card number is required/)
    end

    it "raises on invalid Luhn" do
      service = described_class.new(
        card_number: "4000000000001234",
        expiry_month: "12",
        expiry_year: "2027",
        cvv: "123",
        cardholder_name: "John"
      )
      expect { service.validate! }.to raise_error(PaymentGateway::ValidationError, /Luhn/)
    end

    it "raises on expired card" do
      service = described_class.new(
        card_number: "4000000000001000",
        expiry_month: "01",
        expiry_year: "2020",
        cvv: "123",
        cardholder_name: "John"
      )
      expect { service.validate! }.to raise_error(PaymentGateway::ValidationError, /expired/)
    end

    it "raises on invalid CVV" do
      service = described_class.new(
        card_number: "4000000000001000",
        expiry_month: "12",
        expiry_year: "2027",
        cvv: "12",
        cardholder_name: "John"
      )
      expect { service.validate! }.to raise_error(PaymentGateway::ValidationError, /Invalid CVV/)
    end

    it "raises on missing cardholder name" do
      service = described_class.new(
        card_number: "4000000000001000",
        expiry_month: "12",
        expiry_year: "2027",
        cvv: "123",
        cardholder_name: nil
      )
      expect { service.validate! }.to raise_error(PaymentGateway::ValidationError, /Cardholder name/)
    end
  end

  describe "#card_network" do
    it "detects VISA" do
      service = described_class.new(card_number: "4000000000001000", expiry_month: "12", expiry_year: "2027", cvv: "123", cardholder_name: "John")
      expect(service.card_network).to eq("VISA")
    end

    it "detects MASTERCARD" do
      service = described_class.new(card_number: "5200000000001005", expiry_month: "12", expiry_year: "2027", cvv: "123", cardholder_name: "John")
      expect(service.card_network).to eq("MASTERCARD")
    end
  end

  describe "#requires_3ds?" do
    it "returns true for 3DS-required cards" do
      service = described_class.new(card_number: "4000000000001091", expiry_month: "12", expiry_year: "2027", cvv: "123", cardholder_name: "John")
      expect(service.requires_3ds?).to be true
    end

    it "returns false for non-3DS cards" do
      service = described_class.new(card_number: "4000000000001000", expiry_month: "12", expiry_year: "2027", cvv: "123", cardholder_name: "John")
      expect(service.requires_3ds?).to be false
    end
  end

  describe "#masked_card_number" do
    it "masks card number" do
      service = described_class.new(card_number: "4000000000001000", expiry_month: "12", expiry_year: "2027", cvv: "123", cardholder_name: "John")
      expect(service.masked_card_number).to eq("****1000")
    end
  end
end
