require "test_helper"

class Admin::Users::CreateTest < ActiveSupport::TestCase
  test "creates a regular user" do
    result = Admin::Users::Create.new(email_address: "listener@example.com", password: "password", password_confirmation: "password").call

    assert_predicate result, :success?
    assert_equal "listener@example.com", result.user.email_address
    assert_not_predicate result.user, :admin?
  end

  test "returns validation errors without creating a user" do
    result = Admin::Users::Create.new(email_address: "", password: "password", password_confirmation: "different").call

    assert_not_predicate result, :success?
    assert_includes result.user.errors[:email_address], "can't be blank"
  end
end
