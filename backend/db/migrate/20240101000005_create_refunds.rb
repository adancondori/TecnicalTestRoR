# frozen_string_literal: true

class CreateRefunds < ActiveRecord::Migration[7.0]
  def change
    create_table :refunds, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :payment_request_id, null: false
      t.string :merchant_id, null: false
      t.integer :amount, null: false
      t.string :reference_id
      t.string :reason
      t.string :status, null: false, default: "PENDING"

      t.timestamps
    end

    add_index :refunds, :payment_request_id
    add_index :refunds, :merchant_id
    add_index :refunds, :status
    add_foreign_key :refunds, :payment_requests
    add_foreign_key :refunds, :merchants
  end
end
