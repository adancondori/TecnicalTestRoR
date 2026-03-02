# frozen_string_literal: true

class Refund < ApplicationRecord
  include HasPrefixedId

  prefixed_id "rf"

  STATUSES = %w[PENDING SUCCEEDED FAILED].freeze

  belongs_to :payment_request
  belongs_to :merchant

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
end
