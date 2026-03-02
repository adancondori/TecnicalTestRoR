# frozen_string_literal: true

puts "Seeding merchants..."

merchants = [
  {
    id: "merch-acme-001",
    business_name: "Acme Corp",
    api_key: "pk_test_acme001",
    api_secret: "sk_test_acme001_secret",
    webhook_secret: "whsec_acme001",
    callback_url: "https://acme.example.com/webhooks",
    status: "ACTIVE"
  },
  {
    id: "merch-globex-002",
    business_name: "Globex Corporation",
    api_key: "pk_test_globex002",
    api_secret: "sk_test_globex002_secret",
    webhook_secret: "whsec_globex002",
    callback_url: "https://globex.example.com/webhooks",
    status: "ACTIVE"
  },
  {
    id: "merch-initech-003",
    business_name: "Initech",
    api_key: "pk_test_initech003",
    api_secret: "sk_test_initech003_secret",
    webhook_secret: "whsec_initech003",
    callback_url: "https://initech.example.com/webhooks",
    status: "ACTIVE"
  },
  {
    id: "merch-umbrella-004",
    business_name: "Umbrella Corp",
    api_key: "pk_test_umbrella004",
    api_secret: "sk_test_umbrella004_secret",
    webhook_secret: "whsec_umbrella004",
    callback_url: "https://umbrella.example.com/webhooks",
    status: "ACTIVE"
  },
  {
    id: "merch-suspended-005",
    business_name: "Suspended Inc",
    api_key: "pk_test_susp005",
    api_secret: "sk_test_susp005_secret",
    webhook_secret: "whsec_susp005",
    callback_url: "https://suspended.example.com/webhooks",
    status: "SUSPENDED"
  }
]

merchants.each do |attrs|
  Merchant.find_or_create_by!(id: attrs[:id]) do |m|
    m.assign_attributes(attrs)
  end
end

puts "Seeded #{Merchant.count} merchants (#{Merchant.active.count} active, #{Merchant.where(status: 'SUSPENDED').count} suspended)"
