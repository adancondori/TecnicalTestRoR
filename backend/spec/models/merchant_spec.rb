# frozen_string_literal: true

require "rails_helper"

RSpec.describe Merchant, type: :model do
  describe "validations" do
    subject { build(:merchant) }

    it { is_expected.to validate_presence_of(:business_name) }
    it { is_expected.to validate_presence_of(:api_key) }
    it { is_expected.to validate_uniqueness_of(:api_key).case_insensitive }
    it { is_expected.to validate_presence_of(:api_secret) }
    it { is_expected.to validate_presence_of(:webhook_secret) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[ACTIVE SUSPENDED]) }
  end

  describe "prefixed id" do
    it "generates an id with merch- prefix on create" do
      merchant = create(:merchant, id: nil)
      expect(merchant.id).to start_with("merch-")
    end

    it "does not override an existing id" do
      merchant = create(:merchant, id: "merch-custom-123")
      expect(merchant.id).to eq("merch-custom-123")
    end
  end

  describe "scopes" do
    it ".active returns only active merchants" do
      active = create(:merchant, status: "ACTIVE")
      _suspended = create(:merchant, status: "SUSPENDED")

      expect(Merchant.active).to eq([active])
    end
  end

  describe "#active?" do
    it "returns true for ACTIVE status" do
      expect(build(:merchant, status: "ACTIVE")).to be_active
    end

    it "returns false for SUSPENDED status" do
      expect(build(:merchant, status: "SUSPENDED")).not_to be_active
    end
  end

  describe "#suspended?" do
    it "returns true for SUSPENDED status" do
      expect(build(:merchant, status: "SUSPENDED")).to be_suspended
    end

    it "returns false for ACTIVE status" do
      expect(build(:merchant, status: "ACTIVE")).not_to be_suspended
    end
  end
end
