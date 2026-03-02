# frozen_string_literal: true

class AddRequestIdToResources < ActiveRecord::Migration[7.0]
  def change
    add_column :payment_methods, :request_id, :string
    add_column :payment_requests, :request_id, :string
    add_index :payment_methods, :request_id
    add_index :payment_requests, :request_id
  end
end
