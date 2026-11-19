require "test_helper"

class CallsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @caller = User.create!(email: "caller@example.com", password: "password123", display_name: "Caller")
    @callee = User.create!(email: "callee@example.com", password: "password123", display_name: "Callee")
    @conversation = Conversation.find_or_create_direct(@caller, @callee)
    sign_in @caller
  end

  test "missing provider configuration returns service unavailable" do
    original = ENV.delete("HMS_TEMPLATE_ID")
    post calls_path, params: { conversation_id: @conversation.id, call_type: "audio" }, as: :json
    assert_response :service_unavailable
    assert_equal "Call setup failed", response.parsed_body["error"]
  ensure
    ENV["HMS_TEMPLATE_ID"] = original
  end

  test "cannot start calls outside own conversations" do
    outsider = User.create!(email: "call-outsider@example.com", password: "password123", display_name: "Outsider")
    sign_out @caller
    sign_in outsider
    post calls_path, params: { conversation_id: @conversation.id, call_type: "audio" }, as: :json
    assert_response :unprocessable_entity
  end
end
