# frozen_string_literal: true

class ThreeDSecureController < ApplicationController
  skip_forgery_protection

  def challenge
    @payment_method = PaymentMethod.find(params[:id])
    @challenge = @payment_method.three_d_secure_challenges.find_by(status: "PENDING")

    unless @challenge
      @existing = @payment_method.three_d_secure_challenges.order(created_at: :desc).first
      render :expired
    end
  end

  def verify
    @payment_method = PaymentMethod.find(params[:id])
    @challenge = @payment_method.three_d_secure_challenges.find_by(status: "PENDING")

    unless @challenge
      @existing = @payment_method.three_d_secure_challenges.order(created_at: :desc).first
      render :expired and return
    end

    success = params[:otp] == "1234"
    ThreeDSecure::VerificationService.new(challenge: @challenge, success: success).call
    @result = success ? :success : :failure

    render :result
  end
end
