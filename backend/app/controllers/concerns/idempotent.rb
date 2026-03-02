# frozen_string_literal: true

module Idempotent
  extend ActiveSupport::Concern

  private

  def check_idempotency!(model_class)
    request_id = request.headers["X-Request-ID"]
    return unless request_id.present?

    existing = model_class.find_by(request_id: request_id, merchant_id: current_merchant.id)
    return unless existing

    raise PaymentGateway::DuplicateError.new("Duplicate request. Existing resource: #{existing.id}")
  end

  def save_request_id!(record)
    request_id = request.headers["X-Request-ID"]
    record.update_column(:request_id, request_id) if request_id.present?
  end
end
