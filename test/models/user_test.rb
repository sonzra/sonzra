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

  test "does not define ui_variant attribute" do
    assert_not_includes User.column_names, "ui_variant"
    user = User.new(email_address: "user@example.com", password: "password")
    assert_not user.respond_to?(:ui_variant)
  end

  test "auto-locks registrations when first user is created unless SONZRA_OPEN_REGISTRATION is true" do
    Session.delete_all
    ServerConnection.delete_all
    User.delete_all
    ApplicationSetting.instance.update!(registrations_enabled: true)

    User.create!(email_address: "admin@example.com", password: "password", password_confirmation: "password")

    assert_not ApplicationSetting.instance.registrations_enabled?
  end

  test "does not auto-lock registrations when SONZRA_OPEN_REGISTRATION is true" do
    Session.delete_all
    ServerConnection.delete_all
    User.delete_all
    ApplicationSetting.instance.update!(registrations_enabled: true)

    with_env("SONZRA_OPEN_REGISTRATION" => "true") do
      User.create!(email_address: "admin@example.com", password: "password", password_confirmation: "password")
      assert ApplicationSetting.instance.registrations_enabled?
    end
  end

  private

  def with_env(hash)
    old = {}
    hash.each do |k, v|
      old[k] = ENV[k]
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
    yield
  ensure
    old.each do |k, v|
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
  end
end
