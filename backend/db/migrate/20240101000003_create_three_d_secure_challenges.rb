# frozen_string_literal: true

class CreateThreeDSecureChallenges < ActiveRecord::Migration[7.0]
  def change
    create_table :three_d_secure_challenges, id: false do |t|
      t.string :id, primary_key: true, null: false
      t.string :payment_method_id, null: false
      t.string :payment_request_id
      t.string :status, null: false, default: "PENDING"
      t.string :challenge_url
      t.string :eci_code
      t.string :version, default: "2.0"

      t.timestamps
    end

    add_index :three_d_secure_challenges, :payment_method_id
    add_index :three_d_secure_challenges, :payment_request_id
    add_index :three_d_secure_challenges, :status
    add_foreign_key :three_d_secure_challenges, :payment_methods
  end
end
