require "test_helper"

class ServerConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_connection = ServerConnection.create!(
      name: "Home server",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret"
    )
  end

  test "lists server connections" do
    get server_connections_url

    assert_response :success
    assert_select "h2", "Home server"
  end

  test "shows a server connection" do
    get server_connection_url(@server_connection)

    assert_response :success
    assert_select "h1", "Home server"
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
