# frozen_string_literal: true

require "rails_helper"

RSpec.describe PaymentMethod, type: :model do
  describe "validations" do
    subject { build(:payment_method) }

    it { is_expected.to validate_presence_of(:type_name) }
    it { is_expected.to validate_inclusion_of(:type_name).in_array(%w[CARD EWALLET QR_CODE]) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:reusability) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:merchant) }
    it { is_expected.to have_many(:three_d_secure_challenges) }
  end

  describe "prefixed id" do
    it "generates an id with pm- prefix" do
      pm = create(:payment_method, id: nil)
      expect(pm.id).to start_with("pm-")
    end
  end
end
