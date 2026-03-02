# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentRequest, type: :model do
  describe "validations" do
    subject { build(:payment_request) }

    it { is_expected.to validate_presence_of(:reference_id) }
    it { is_expected.to validate_uniqueness_of(:reference_id).scoped_to(:merchant_id).case_insensitive }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).is_greater_than(0) }
    it { is_expected.to validate_presence_of(:currency) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:capture_method) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:merchant) }
    it { is_expected.to belong_to(:payment_method).optional }
  end

  describe "state machine" do
    let(:pr) { create(:payment_request, status: "PENDING") }

    it "transitions from PENDING to AUTHORIZED" do
      pr.transition_to!("AUTHORIZED")
      expect(pr.status).to eq("AUTHORIZED")
    end

    it "transitions from PENDING to REQUIRES_ACTION" do
      pr.transition_to!("REQUIRES_ACTION")
      expect(pr.status).to eq("REQUIRES_ACTION")
    end

    it "raises on invalid transition" do
      expect { pr.transition_to!("SUCCEEDED") }.to raise_error(PaymentGateway::InvalidState)
    end

    it "transitions full auto-capture flow" do
      pr.transition_to!("AUTHORIZED")
      pr.transition_to!("CAPTURED")
      pr.transition_to!("SUCCEEDED")
      expect(pr.status).to eq("SUCCEEDED")
    end
  end
end
