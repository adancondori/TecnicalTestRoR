# frozen_string_literal: true

class Merchant < ApplicationRecord
  include HasPrefixedId

  prefixed_id "merch"

  STATUSES = %w[ACTIVE SUSPENDED].freeze

  has_many :payment_methods, dependent: :destroy
  has_many :payment_requests, dependent: :destroy
  has_many :refunds, dependent: :destroy
  has_many :webhook_events, dependent: :destroy

  validates :business_name, presence: true
  validates :api_key, presence: true, uniqueness: true
  validates :api_secret, presence: true
  validates :webhook_secret, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "ACTIVE") }

  def active?
    status == "ACTIVE"
  end

  def suspended?
    status == "SUSPENDED"
  end
end
