require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "makes the first created user an administrator" do
    Session.delete_all
    ServerConnection.delete_all
    User.delete_all

    first_user = User.create!(email_address: "first@example.com", password: "password", password_confirmation: "password")
    later_user = User.create!(email_address: "later@example.com", password: "password", password_confirmation: "password")

    assert_predicate first_user, :admin?
    assert_not_predicate later_user, :admin?
  end
end
