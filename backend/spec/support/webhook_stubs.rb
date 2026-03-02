# frozen_string_literal: true

# Globally stub all external webhook HTTP calls so WebMock doesn't block them.
# The webhook_service_spec defines its own targeted stubs before these run.
RSpec.configure do |config|
  config.before(:each) do
    # Catch-all: any external POST with webhook headers returns 200
    stub_request(:post, /.*/)
      .with(headers: { "X-Webhook-Event" => /.*/ })
      .to_return(status: 200, body: "OK")
  end
end
