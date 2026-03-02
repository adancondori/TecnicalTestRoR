# frozen_string_literal: true

class ThreeDSecureChallenge < ApplicationRecord
  include HasPrefixedId

  prefixed_id "3ds"

  STATUSES = %w[PENDING COMPLETED FAILED].freeze

  belongs_to :payment_method

  validates :status, presence: true, inclusion: { in: STATUSES }

  def pending?
    status == "PENDING"
  end

  def completed?
    status == "COMPLETED"
  end

  def failed?
    status == "FAILED"
  end
end
