# frozen_string_literal: true

class CreatePaymentMethods < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_methods, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :merchant_id, null: false
      t.string :type_name, null: false
      t.string :status, null: false, default: "ACTIVE"
      t.string :reusability, null: false, default: "ONE_TIME_USE"
      t.string :token_id
      t.string :card_fingerprint
      t.string :masked_card_number
      t.string :card_network
      t.string :card_type
      t.integer :expiry_month
      t.integer :expiry_year
      t.string :cardholder_name
      t.string :cardholder_email
      t.string :channel_code
      t.json :metadata

      t.timestamps
    end

    add_index :payment_methods, :merchant_id
    add_index :payment_methods, :token_id, unique: true
    add_index :payment_methods, :status
    add_foreign_key :payment_methods, :merchants
  end
end
