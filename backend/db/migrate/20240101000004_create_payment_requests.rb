# frozen_string_literal: true

class CreatePaymentRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_requests, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :merchant_id, null: false
      t.string :payment_method_id
      t.string :reference_id, null: false
      t.integer :amount, null: false
      t.string :currency, null: false, default: "USD"
      t.string :status, null: false, default: "PENDING"
      t.string :capture_method, null: false, default: "AUTOMATIC"
      t.string :description
      t.string :failure_code
      t.string :callback_url
      t.string :success_return_url
      t.string :failure_return_url
      t.integer :captured_amount, default: 0
      t.integer :refunded_amount, default: 0
      t.string :payment_type
      t.string :channel_code
      t.string :qr_string
      t.string :ewallet_url
      t.json :metadata

      t.timestamps
    end

    add_index :payment_requests, :merchant_id
    add_index :payment_requests, :payment_method_id
    add_index :payment_requests, [:merchant_id, :reference_id], unique: true
    add_index :payment_requests, :status
    add_foreign_key :payment_requests, :merchants
    add_foreign_key :payment_requests, :payment_methods
  end
end
