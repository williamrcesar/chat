require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = User.create!(email: "user-admin@example.com", password: "password123", display_name: "Admin", role: :admin)
    @supervisor = User.create!(email: "user-supervisor@example.com", password: "password123", display_name: "Supervisor")
    company = Company.create!(name: "Company", nickname: "admin_test", owner: @admin, status: :active)
    CompanyAttendant.create!(company: company, user: @supervisor, role_name: "Support", is_supervisor: true, status: :available)
  end

  test "company supervisors cannot promote themselves to global admin" do
    sign_in @supervisor
    patch toggle_admin_admin_user_path(@supervisor)
    assert_response :forbidden
    assert @supervisor.reload.role_regular?
  end

  test "company supervisors cannot edit global users" do
    sign_in @supervisor
    patch admin_user_path(@admin), params: { user: { email: "hijacked@example.com", role: "regular" } }
    assert_response :forbidden
    assert_equal "user-admin@example.com", @admin.reload.email
    assert @admin.role_admin?
  end

  test "role changes cannot bypass the dedicated admin action" do
    sign_in @admin
    patch admin_user_path(@admin), params: { user: { display_name: "Updated", role: "regular" } }
    assert_response :redirect
    assert_equal "Updated", @admin.reload.display_name
    assert @admin.role_admin?
  end

  test "global admins can promote other users through the dedicated action" do
    sign_in @admin
    patch toggle_admin_admin_user_path(@supervisor)
    assert_response :redirect
    assert @supervisor.reload.role_admin?
  end
end
