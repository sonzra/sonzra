require "test_helper"

class HiddenGenreTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @connection = ServerConnection.create!(name: "Home Jellyfin", provider: :jellyfin, base_url: "https://jellyfin.example.com", username: "bruno", password: "password", user: @user)
  end

  test "validates presence of name" do
    hidden_genre = HiddenGenre.new(user: @user, server_connection: @connection, name: "")
    assert_not hidden_genre.valid?
    assert_includes hidden_genre.errors[:name], "can't be blank"
  end

  test "normalizes name by stripping leading and trailing whitespace" do
    hidden_genre = HiddenGenre.create!(user: @user, server_connection: @connection, name: "  Ambient  ")
    assert_equal "Ambient", hidden_genre.name
  end

  test "enforces case-insensitive uniqueness of name scoped to user and server connection" do
    HiddenGenre.create!(user: @user, server_connection: @connection, name: "Holiday")

    duplicate = HiddenGenre.new(user: @user, server_connection: @connection, name: "holiday")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"

    # Permitted for another user or another connection
    other_user = users(:two)
    assert HiddenGenre.new(user: other_user, server_connection: @connection, name: "Holiday").valid?
  end

  test "destroys associated hidden genres when user is destroyed" do
    hidden_genre = HiddenGenre.create!(user: @user, server_connection: @connection, name: "Holiday")
    @user.destroy!
    assert_not HiddenGenre.exists?(hidden_genre.id)
  end

  test "destroys associated hidden genres when server connection is destroyed" do
    hidden_genre = HiddenGenre.create!(user: @user, server_connection: @connection, name: "Holiday")
    @connection.destroy!
    assert_not HiddenGenre.exists?(hidden_genre.id)
  end
end
