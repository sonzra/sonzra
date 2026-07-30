require "test_helper"

class ServerConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_connection = ServerConnection.create!(
      name: "Home server",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "lists server connections" do
    get server_connections_url

    assert_response :success
    assert_select "h1", "Server"
    assert_select "h2", "Home server"
    assert_select "a.connection-card__edit[href='#{edit_server_connection_path(@server_connection)}']"
    assert_select "a[href='#{new_server_connection_path}']", count: 0
  end

  test "shows a server connection" do
    get server_connection_url(@server_connection)

    assert_response :success
    assert_select "h1", "Home server"
  end

  test "renders an edit cancel link back to the servers list" do
    get edit_server_connection_url(@server_connection)

    assert_response :success
    assert_select "a.secondary-button[href='#{server_connections_path}']", "Cancel"
  end

  test "creates a server connection" do
    assert_difference("ServerConnection.count") do
      post server_connections_url, params: {
        server_connection: connection_params.merge(name: "Travel server")
      }
    end

    assert_redirected_to server_connection_url(ServerConnection.order(:created_at).last)
  end

  test "updates a server connection without replacing a blank password" do
    patch server_connection_url(@server_connection), params: {
      server_connection: connection_params.merge(name: "Renamed server", password: "")
    }

    assert_redirected_to server_connection_url(@server_connection)
    assert_equal "Renamed server", @server_connection.reload.name
    assert_equal "secret", @server_connection.password
  end

  test "destroys a server connection" do
    assert_difference("ServerConnection.count", -1) do
      delete server_connection_url(@server_connection)
    end

    assert_redirected_to server_connections_url
  end

  test "does not expose another user's server connection" do
    other_user = User.create!(email_address: "other@example.com", password: "password", password_confirmation: "password")
    other_connection = ServerConnection.create!(connection_params.merge(name: "Private server", user: other_user))

    get server_connection_url(other_connection)

    assert_response :not_found
  end

  private

  def connection_params
    {
      provider: "jellyfin",
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret"
    }
  end
end
