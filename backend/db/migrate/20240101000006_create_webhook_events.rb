# frozen_string_literal: true

class CreateWebhookEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :webhook_events, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :merchant_id, null: false
      t.string :event_type, null: false
      t.json :payload
      t.string :status, null: false, default: "PENDING"
      t.integer :attempts, default: 0
      t.datetime :last_attempt_at
      t.integer :response_code
      t.text :response_body

      t.timestamps
    end

    add_index :webhook_events, :merchant_id
    add_index :webhook_events, :event_type
    add_index :webhook_events, :status
    add_foreign_key :webhook_events, :merchants
  end
end
