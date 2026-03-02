# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2024_01_01_000007) do
  create_table "merchants", id: :string, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "business_name", null: false
    t.string "api_key", null: false
    t.string "api_secret", null: false
    t.string "webhook_secret", null: false
    t.string "callback_url"
    t.string "status", default: "ACTIVE", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key"], name: "index_merchants_on_api_key", unique: true
    t.index ["status"], name: "index_merchants_on_status"
  end

  create_table "payment_methods", id: :string, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "merchant_id", null: false
    t.string "type_name", null: false
    t.string "status", default: "ACTIVE", null: false
    t.string "reusability", default: "ONE_TIME_USE", null: false
    t.string "token_id"
    t.string "card_fingerprint"
    t.string "masked_card_number"
    t.string "card_network"
    t.string "card_type"
    t.integer "expiry_month"
    t.integer "expiry_year"
    t.string "cardholder_name"
    t.string "cardholder_email"
    t.string "channel_code"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "request_id"
    t.index ["merchant_id"], name: "index_payment_methods_on_merchant_id"
    t.index ["request_id"], name: "index_payment_methods_on_request_id"
    t.index ["status"], name: "index_payment_methods_on_status"
    t.index ["token_id"], name: "index_payment_methods_on_token_id", unique: true
  end

  create_table "payment_requests", id: :string, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "merchant_id", null: false
    t.string "payment_method_id"
    t.string "reference_id", null: false
    t.integer "amount", null: false
    t.string "currency", default: "USD", null: false
    t.string "status", default: "PENDING", null: false
    t.string "capture_method", default: "AUTOMATIC", null: false
    t.string "description"
    t.string "failure_code"
    t.string "callback_url"
    t.string "success_return_url"
    t.string "failure_return_url"
    t.integer "captured_amount", default: 0
    t.integer "refunded_amount", default: 0
    t.string "payment_type"
    t.string "channel_code"
    t.string "qr_string"
    t.string "ewallet_url"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "request_id"
    t.index ["merchant_id", "reference_id"], name: "index_payment_requests_on_merchant_id_and_reference_id", unique: true
    t.index ["merchant_id"], name: "index_payment_requests_on_merchant_id"
    t.index ["payment_method_id"], name: "index_payment_requests_on_payment_method_id"
    t.index ["request_id"], name: "index_payment_requests_on_request_id"
    t.index ["status"], name: "index_payment_requests_on_status"
  end

  create_table "refunds", id: :string, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "payment_request_id", null: false
    t.string "merchant_id", null: false
    t.integer "amount", null: false
    t.string "reference_id"
    t.string "reason"
    t.string "status", default: "PENDING", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_id"], name: "index_refunds_on_merchant_id"
    t.index ["payment_request_id"], name: "index_refunds_on_payment_request_id"
    t.index ["status"], name: "index_refunds_on_status"
  end

  create_table "three_d_secure_challenges", id: :string, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "payment_method_id", null: false
    t.string "payment_request_id"
    t.string "status", default: "PENDING", null: false
    t.string "challenge_url"
    t.string "eci_code"
    t.string "version", default: "2.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_method_id"], name: "index_three_d_secure_challenges_on_payment_method_id"
    t.index ["payment_request_id"], name: "index_three_d_secure_challenges_on_payment_request_id"
    t.index ["status"], name: "index_three_d_secure_challenges_on_status"
  end

  create_table "webhook_events", id: :string, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "merchant_id", null: false
    t.string "event_type", null: false
    t.json "payload"
    t.string "status", default: "PENDING", null: false
    t.integer "attempts", default: 0
    t.datetime "last_attempt_at"
    t.integer "response_code"
    t.text "response_body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_webhook_events_on_event_type"
    t.index ["merchant_id"], name: "index_webhook_events_on_merchant_id"
    t.index ["status"], name: "index_webhook_events_on_status"
  end

  add_foreign_key "payment_methods", "merchants"
  add_foreign_key "payment_requests", "merchants"
  add_foreign_key "payment_requests", "payment_methods"
  add_foreign_key "refunds", "merchants"
  add_foreign_key "refunds", "payment_requests"
  add_foreign_key "three_d_secure_challenges", "payment_methods"
  add_foreign_key "webhook_events", "merchants"
end
