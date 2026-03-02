# frozen_string_literal: true

class MerchantsController < ApplicationController
  before_action :set_merchant, only: [:show, :edit, :update, :destroy, :regenerate_webhook_secret]

  def index
    @merchants = Merchant.order(:business_name)
  end

  def new
    @merchant = Merchant.new
  end

  def create
    @merchant = Merchant.new(merchant_params)
    @merchant.api_key = "pk_test_#{SecureRandom.hex(12)}"
    @merchant.api_secret = "sk_test_#{SecureRandom.hex(20)}"
    @merchant.webhook_secret = "whsec_#{SecureRandom.hex(16)}"

    if @merchant.save
      redirect_to merchant_path(@merchant), notice: "Merchant created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @payment_requests = @merchant.payment_requests
                          .includes(:payment_method, :refunds)
                          .order(created_at: :desc)

    @payment_requests = @payment_requests.where(status: params[:status]) if params[:status].present?

    if params[:date_from].present?
      @payment_requests = @payment_requests.where("created_at >= ?", Date.parse(params[:date_from]).beginning_of_day)
    end

    if params[:date_to].present?
      @payment_requests = @payment_requests.where("created_at <= ?", Date.parse(params[:date_to]).end_of_day)
    end
  end

  def edit; end

  def update
    if @merchant.update(merchant_params)
      redirect_to merchant_path(@merchant), notice: "Merchant updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @merchant.destroy
    redirect_to merchants_path, notice: "Merchant deleted successfully."
  end

  def regenerate_webhook_secret
    @merchant.update!(webhook_secret: "whsec_#{SecureRandom.hex(16)}")
    redirect_to merchant_path(@merchant), notice: "Webhook secret regenerated successfully."
  end

  private

  def set_merchant
    @merchant = Merchant.find(params[:id])
  end

  def merchant_params
    params.require(:merchant).permit(:business_name, :status, :callback_url)
  end
end
