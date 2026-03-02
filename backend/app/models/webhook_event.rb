# frozen_string_literal: true

class WebhookEvent < ApplicationRecord
  include HasPrefixedId

  prefixed_id "we"

  STATUSES = %w[PENDING DELIVERED FAILED].freeze

  belongs_to :merchant

  validates :event_type, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
end
