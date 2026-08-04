require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup { users(:one).update!(admin: true) }

  test "lists users and creates a new account" do
    get admin_users_path

    assert_response :success
    assert_select "h1", "Users"
    assert_select "a[href='#{new_admin_user_path}']", "Add user"

    assert_difference("User.count") do
      post admin_users_path, params: { user: { email_address: "listener@example.com", password: "password", password_confirmation: "password" } }
    end

    assert_redirected_to admin_users_path
    assert_not_predicate User.find_by!(email_address: "listener@example.com"), :admin?
  end

  test "does not let non-administrators manage users" do
    users(:one).update!(admin: false)

    get admin_users_path

    assert_redirected_to root_path
  end
end
