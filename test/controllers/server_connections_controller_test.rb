require "test_helper"

class ServerConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_connection = ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home server", provider: :jellyfin, base_url: "https://jellyfin.example.com"),
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

  test "connects a second user to the configured server without allowing a second server" do
    sign_out
    user = User.create!(email_address: "new-user@example.com", password: "password", password_confirmation: "password")
    sign_in_as(user)

    assert_difference("ServerConnection.count") do
      post server_connections_url, params: {
        server_connection: { username: "new-user", password: "secret" }
      }
    end

    assert_redirected_to server_connection_url(ServerConnection.order(:created_at).last)
    assert_equal @server_connection.media_server, ServerConnection.order(:created_at).last.media_server
  end

  test "connects a user through Jellyfin Quick Connect without storing a password" do
    @server_connection.destroy!
    client = quick_connect_client

    with_jellyfin_client(client) do
      post start_quick_connect_server_connections_url, params: { server_connection: { name: "Home server", provider: "jellyfin", base_url: "https://jellyfin.example.com" } }
      assert_redirected_to quick_connect_server_connections_url
      follow_redirect!
      assert_select ".quick-connect__code", "ABC123"

      get quick_connect_status_server_connections_url, as: :json
    end

    assert_response :success
    connection = users(:one).server_connections.find_by!(media_server: @server_connection.media_server)
    assert_equal "Bruno", connection.username
    assert_equal "access-token", connection.access_token
    assert_nil connection.password
    assert_equal "user-id", session[:server_remote_user_ids][connection.id.to_s]
  end

  test "allows the administrator to configure the first shared server" do
    @server_connection.destroy!
    @server_connection.media_server.destroy!

    assert_difference([ "MediaServer.count", "ServerConnection.count" ]) do
      post server_connections_url, params: {
        server_connection: {
          name: "Shared Jellyfin", provider: "jellyfin", base_url: "https://music.example.com",
          username: "bruno", password: "secret"
        }
      }
    end

    connection = ServerConnection.order(:created_at).last
    assert_equal "Shared Jellyfin", connection.name
    assert_equal "https://music.example.com", connection.base_url
  end

  test "does not let a non-administrator configure the shared server" do
    @server_connection.destroy!
    @server_connection.media_server.destroy!
    sign_out
    user = User.create!(email_address: "member@example.com", password: "password", password_confirmation: "password")
    sign_in_as(user)

    assert_no_difference([ "MediaServer.count", "ServerConnection.count" ]) do
      post server_connections_url, params: {
        server_connection: { name: "Shared Jellyfin", provider: "jellyfin", base_url: "https://music.example.com", username: "member", password: "secret" }
      }
    end

    assert_response :unprocessable_entity
  end

  test "updates a server connection without replacing a blank password" do
    patch server_connection_url(@server_connection), params: {
      server_connection: { name: "Renamed server", provider: "jellyfin", base_url: "https://jellyfin.example.com", username: "bruno", password: "" }
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
    other_connection = ServerConnection.create!(username: "other", password: "secret", media_server: @server_connection.media_server, user: other_user)

    get server_connection_url(other_connection)

    assert_response :not_found
  end

  private

  def quick_connect_client
    Object.new.tap do |client|
      client.define_singleton_method(:initiate_quick_connect) { { "Secret" => "quick-secret", "Code" => "ABC123" } }
      client.define_singleton_method(:quick_connect_state) { |_| { "Authenticated" => true } }
      client.define_singleton_method(:authenticate_with_quick_connect) { |_| { "AccessToken" => "access-token", "User" => { "Id" => "user-id", "Name" => "Bruno" } } }
    end
  end

  def with_jellyfin_client(client)
    client_class = Integrations::Jellyfin::Client
    client_class.singleton_class.alias_method :new_before_quick_connect_test, :new
    client_class.define_singleton_method(:new) { |**| client }
    yield
  ensure
    client_class.singleton_class.alias_method :new, :new_before_quick_connect_test
    client_class.singleton_class.remove_method :new_before_quick_connect_test
  end
end
