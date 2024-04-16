require "test_helper"

class Api::FeaturesControllerTest < ActionDispatch::IntegrationTest
    test "should get index" do
        get api_features_url
        assert_response :success
    end

    test "should filter by mag_type" do
        get api_features_url, params: { mag_type: "ml" }
        assert_response :success
        assert_not_empty response.body
    end
end