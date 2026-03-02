# frozen_string_literal: true

class CreateMerchants < ActiveRecord::Migration[7.0]
  def change
    create_table :merchants, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :business_name, null: false
      t.string :api_key, null: false
      t.string :api_secret, null: false
      t.string :webhook_secret, null: false
      t.string :callback_url
      t.string :status, null: false, default: "ACTIVE"

      t.timestamps
    end

    add_index :merchants, :api_key, unique: true
    add_index :merchants, :status
  end
end
