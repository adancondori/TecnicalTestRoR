# frozen_string_literal: true

module HasPrefixedId
  extend ActiveSupport::Concern

  class_methods do
    def prefixed_id(prefix)
      before_create do
        self.id = "#{prefix}-#{SecureRandom.uuid}" if id.blank?
      end
    end
  end
end
