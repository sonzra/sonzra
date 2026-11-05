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
    assert_select "a.primary-button", "Add server"
    assert_select "form[action='#{test_connection_server_connection_path(@server_connection)}'] button", "Test"
    assert_select "form[action='#{server_connection_path(@server_connection)}'] input[name='_method'][value='delete']"
  end

  test "shows a server connection" do
    get server_connection_url(@server_connection)

    assert_response :success
    assert_select "h1", "Home server"
  end

  test "lets an administrator choose Plex when adding a shared server" do
    get new_server_connection_url(setup: true)

    assert_response :success
    assert_select "select[name='server_connection[provider]'] option[value='plex']", "Plex"
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

  test "returns to the server index after testing a connection from there" do
    post test_connection_server_connection_url(@server_connection), headers: { "Referer" => server_connections_url }

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

  test "renders reconnect modal frame for server connection" do
    get reconnect_server_connection_url(@server_connection)

    assert_response :success
    assert_select "turbo-frame#reconnect_modal"
    assert_select "form[action='#{reconnect_server_connection_path(@server_connection)}']"
    assert_select "input[name='server_connection[username]']"
    assert_select "input[name='server_connection[password]']"
  end

  test "reconnects server connection with updated credentials via turbo stream" do
    fake_client = Object.new
    fake_client.define_singleton_method(:authenticate) { "Bruno" }
    fake_client.define_singleton_method(:access_token) { "fresh-reconnect-token" }

    original_for = Integrations::Client.method(:for)
    Integrations::Client.define_singleton_method(:for) { |*_args, **_kwargs| fake_client }

    begin
      patch reconnect_server_connection_url(@server_connection), params: {
        server_connection: { username: "bruno", password: "new-password" }
      }, as: :turbo_stream

      assert_response :success
      assert_equal "fresh-reconnect-token", session.dig(:server_access_tokens, @server_connection.id.to_s)
      assert_equal "new-password", @server_connection.reload.password
      assert_includes response.body, %(target="connection-alert-#{@server_connection.id}")
      assert_includes response.body, %(action="remove")
    ensure
      Integrations::Client.define_singleton_method(:for, original_for)
    end
  end

  test "renders persistent connection alerts shell in application layout" do
    get server_connections_url

    assert_response :success
    assert_select "#connection_alerts[data-turbo-permanent]"
    assert_select "dialog#reconnect-dialog"
  end

  test "renders reconnect banner in connection alerts when connection alert session is present" do
    result = ServerConnections::FetchHomeContentResultData.new(
      content: nil,
      access_token: nil,
      message: "Session expired."
    )
    service = Object.new
    service.define_singleton_method(:call) { result }
    original_new = ServerConnections::FetchCachedHomeContent.method(:new)
    ServerConnections::FetchCachedHomeContent.define_singleton_method(:new) { |*_args, **_kwargs| service }

    begin
      get home_content_url
      assert_response :success

      get server_connections_url
      assert_response :success
      assert_select "#connection-alert-#{@server_connection.id}"
      assert_select ".connection-alert__text strong", "Connection to #{@server_connection.name} expired."
    ensure
      ServerConnections::FetchCachedHomeContent.define_singleton_method(:new, original_new)
    end
  end

  test "reconnect does not save invalid credentials when authentication fails" do
    old_password = @server_connection.password
    fake_client = Object.new
    fake_client.define_singleton_method(:authenticate) do
      raise Integrations::Jellyfin::Client::AuthenticationError, "Invalid username or password."
    end

    original_for = Integrations::Client.method(:for)
    Integrations::Client.define_singleton_method(:for) { |*_args, **_kwargs| fake_client }

    begin
      patch reconnect_server_connection_url(@server_connection), params: {
        server_connection: { username: "bruno", password: "wrong-password" }
      }

      assert_response :unprocessable_entity
      assert_equal old_password, @server_connection.reload.password
      assert_select ".form-errors", text: /Invalid username or password/
    ensure
      Integrations::Client.define_singleton_method(:for, original_for)
    end
  end

  test "completes plex quick connect status and stores access token without NameError" do
    plex_server = MediaServer.create!(provider: :plex, base_url: "https://plex.example.com", name: "Plex Server")
    fake_client = Object.new
    fake_client.define_singleton_method(:initiate_pin) do |**|
      { "id" => "123", "code" => "ABCD", "url" => "https://plex.tv/pin" }
    end
    fake_client.define_singleton_method(:pin_status) { |**| "fresh-plex-token" }
    fake_client.define_singleton_method(:authenticated_account_name) { |**| "PlexUser" }

    with_plex_client(fake_client) do
      post start_quick_connect_server_connections_url, params: {
        server_connection: { media_server_id: plex_server.id }
      }
      assert_redirected_to quick_connect_server_connections_url

      get quick_connect_status_server_connections_url, as: :json
      assert_response :success

      response_data = JSON.parse(response.body)
      assert_equal "connected", response_data["status"]

      connection = users(:one).server_connections.find_by!(media_server: plex_server)
      assert_equal "PlexUser", connection.username
      assert_equal "fresh-plex-token", connection.access_token
      assert_equal "fresh-plex-token", session.dig(:server_access_tokens, connection.id.to_s)
    end
  end

  test "reconnect initiates quick connect session for plex connection" do
    plex_server = MediaServer.create!(provider: :plex, base_url: "https://plex.example.com", name: "Plex Server")
    plex_connection = users(:one).server_connections.create!(
      media_server: plex_server,
      username: "PlexUser",
      access_token: "expired-token"
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:initiate_pin) do |**|
      { "id" => "999", "code" => "WXYZ", "url" => "https://plex.tv/pin" }
    end

    with_plex_client(fake_client) do
      get reconnect_server_connection_url(plex_connection)
      assert_response :success

      assert_equal "plex", session.dig(:quick_connect, "provider")
      assert_equal "999", session.dig(:quick_connect, "id")
      assert_equal plex_connection.id, session.dig(:quick_connect, "reconnect_connection_id")

      # Clicking link to quick_connect does not redirect away with error
      get quick_connect_server_connections_url
      assert_response :success
      assert_select "a[href='https://plex.tv/pin']", text: "Open Plex sign-in"
    end
  end

  test "prioritizes and synchronizes updated database token over stale session token" do
    fake_client = Object.new
    fake_client.define_singleton_method(:authenticate) { "Bruno" }
    fake_client.define_singleton_method(:access_token) { "stale-session-token" }
    original_for = Integrations::Client.method(:for)
    Integrations::Client.define_singleton_method(:for) { |*_args, **_kwargs| fake_client }

    begin
      patch reconnect_server_connection_url(@server_connection), params: {
        server_connection: { username: "bruno", password: "new-password" }
      }
      assert_equal "stale-session-token", session.dig(:server_access_tokens, @server_connection.id.to_s)

      # Now simulate background job updating the DB token
      @server_connection.update_column(:access_token, "database-fresh-token")

      get server_connections_url
      assert_equal "database-fresh-token", @controller.send(:server_access_token, @server_connection)
      assert_equal "database-fresh-token", session.dig(:server_access_tokens, @server_connection.id.to_s)
    ensure
      Integrations::Client.define_singleton_method(:for, original_for)
    end
  end

  def with_plex_client(client)
    client_class = Integrations::Plex::Client
    client_class.singleton_class.alias_method :new_before_plex_test, :new
    client_class.define_singleton_method(:new) { |**| client }
    yield
  ensure
    client_class.singleton_class.alias_method :new, :new_before_plex_test
    client_class.singleton_class.remove_method :new_before_plex_test
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
