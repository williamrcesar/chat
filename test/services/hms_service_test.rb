require "test_helper"

class HmsServiceTest < ActiveSupport::TestCase
  test "missing signing credentials produce a provider error" do
    original = ENV.delete("HMS_APP_SECRET")
    assert_raises(HmsService::Error) do
      HmsService.generate_auth_token(room_id: "room", user_id: 1)
    end
    assert_raises(HmsService::Error) { HmsService.generate_management_token }
  ensure
    ENV["HMS_APP_SECRET"] = original
  end
end
