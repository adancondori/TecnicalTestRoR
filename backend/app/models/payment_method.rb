# frozen_string_literal: true

class PaymentMethod < ApplicationRecord
  include HasPrefixedId

  prefixed_id "pm"

  TYPES = %w[CARD EWALLET QR_CODE].freeze
  STATUSES = %w[ACTIVE PENDING_AUTHENTICATION FAILED EXPIRED].freeze
  REUSABILITIES = %w[ONE_TIME_USE MULTIPLE_USE].freeze

  belongs_to :merchant
  has_many :three_d_secure_challenges, dependent: :destroy
  has_many :payment_requests, dependent: :nullify

  validates :type_name, presence: true, inclusion: { in: TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :reusability, presence: true, inclusion: { in: REUSABILITIES }
  validates :token_id, uniqueness: true, allow_nil: true

  scope :active, -> { where(status: "ACTIVE") }

  def pending_authentication?
    status == "PENDING_AUTHENTICATION"
  end

  def active?
    status == "ACTIVE"
  end
end
