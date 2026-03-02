# frozen_string_literal: true

class PaymentRequest < ApplicationRecord
  include HasPrefixedId
  include HasStateMachine

  prefixed_id "pr"

  STATUSES = %w[PENDING REQUIRES_ACTION AUTHORIZED CAPTURED SUCCEEDED FAILED VOIDED REFUNDED].freeze
  CAPTURE_METHODS = %w[AUTOMATIC MANUAL].freeze
  PAYMENT_TYPES = %w[CARD EWALLET QR_CODE].freeze

  state_machine(
    "PENDING" => %w[REQUIRES_ACTION AUTHORIZED FAILED],
    "REQUIRES_ACTION" => %w[AUTHORIZED FAILED],
    "AUTHORIZED" => %w[CAPTURED VOIDED],
    "CAPTURED" => %w[SUCCEEDED REFUNDED],
    "SUCCEEDED" => %w[REFUNDED]
  )

  belongs_to :merchant
  belongs_to :payment_method, optional: true
  has_many :refunds, dependent: :destroy

  validates :reference_id, presence: true, uniqueness: { scope: :merchant_id }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :capture_method, presence: true, inclusion: { in: CAPTURE_METHODS }
end
