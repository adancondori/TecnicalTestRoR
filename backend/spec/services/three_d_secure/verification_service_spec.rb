# frozen_string_literal: true

require "rails_helper"

RSpec.describe ThreeDSecure::VerificationService do
  let(:merchant) { create(:merchant) }
  let(:payment_method) { create(:payment_method, :pending_authentication, merchant: merchant) }
  let(:challenge) { create(:three_d_secure_challenge, payment_method: payment_method) }

  describe "success without payment_request" do
    subject { described_class.new(challenge: challenge, success: true).call }

    it "completes the challenge" do
      subject
      expect(challenge.reload.status).to eq("COMPLETED")
      expect(challenge.eci_code).to eq("05")
    end

    it "activates the payment method" do
      subject
      expect(payment_method.reload.status).to eq("ACTIVE")
    end

    it "sends payment_method.auth_completed webhook" do
      expect(WebhookService).to receive(:deliver!).with(
        merchant: merchant,
        event_type: "payment_method.auth_completed",
        payload: anything
      )
      subject
    end
  end

  describe "success with payment_request" do
    let(:payment_request) do
      create(:payment_request, :requires_action, merchant: merchant, payment_method: payment_method)
    end
    let(:challenge) do
      create(:three_d_secure_challenge, payment_method: payment_method, payment_request_id: payment_request.id)
    end

    subject { described_class.new(challenge: challenge, success: true).call }

    it "sends auth webhook and delegates to AfterThreeDsService" do
      expect(WebhookService).to receive(:deliver!).with(
        merchant: merchant,
        event_type: "payment_method.auth_completed",
        payload: anything
      ).ordered

      # AfterThreeDsService sends payment webhooks
      expect(WebhookService).to receive(:deliver!).with(
        merchant: merchant,
        event_type: "payment.authorized",
        payload: anything
      ).ordered

      expect(WebhookService).to receive(:deliver!).with(
        merchant: merchant,
        event_type: "payment.captured",
        payload: anything
      ).ordered

      expect(WebhookService).to receive(:deliver!).with(
        merchant: merchant,
        event_type: "payment.succeeded",
        payload: anything
      ).ordered

      subject
    end

    it "transitions payment to SUCCEEDED" do
      subject
      expect(payment_request.reload.status).to eq("SUCCEEDED")
    end
  end

  describe "failure without payment_request" do
    subject { described_class.new(challenge: challenge, success: false).call }

    it "fails the challenge" do
      subject
      expect(challenge.reload.status).to eq("FAILED")
    end

    it "fails the payment method" do
      subject
      expect(payment_method.reload.status).to eq("FAILED")
    end

    it "sends payment_method.auth_failed webhook" do
      expect(WebhookService).to receive(:deliver!).with(
        merchant: merchant,
        event_type: "payment_method.auth_failed",
        payload: anything
      )
      subject
    end
  end

  describe "failure with payment_request" do
    let(:payment_request) do
      create(:payment_request, :requires_action, merchant: merchant, payment_method: payment_method)
    end
    let(:challenge) do
      create(:three_d_secure_challenge, payment_method: payment_method, payment_request_id: payment_request.id)
    end

    subject { described_class.new(challenge: challenge, success: false).call }

    it "sends auth_failed webhook and payment.failed webhook" do
      expect(WebhookService).to receive(:deliver!).with(
        merchant: merchant,
        event_type: "payment_method.auth_failed",
        payload: anything
      ).ordered

      expect(WebhookService).to receive(:deliver!).with(
        merchant: merchant,
        event_type: "payment.failed",
        payload: anything
      ).ordered

      subject
    end

    it "transitions payment to FAILED" do
      subject
      expect(payment_request.reload.status).to eq("FAILED")
      expect(payment_request.failure_code).to eq("3DS_AUTHENTICATION_FAILED")
    end
  end
end
