require "test_helper"

class Api::CommentsControllerTest < ActionDispatch::IntegrationTest
    setup do
        @feature = features(:one)
    end

    test "should create comment" do
        assert_difference('Comment.count') do
        post api_feature_comments_url(@feature), params: { comment: { body: "New Comment" } }
        end
        assert_response :created
    end
end