# frozen_string_literal: true

module HasStateMachine
  extend ActiveSupport::Concern

  class_methods do
    def state_machine(transitions)
      define_method(:allowed_transitions) { transitions }

      define_method(:can_transition_to?) do |new_status|
        allowed = transitions[status]
        allowed.is_a?(Array) && allowed.include?(new_status)
      end

      define_method(:transition_to!) do |new_status|
        unless can_transition_to?(new_status)
          raise PaymentGateway::InvalidState,
            "Cannot transition from #{status} to #{new_status}"
        end
        update!(status: new_status)
      end
    end
  end
end
