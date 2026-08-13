require "test_helper"

class ActiveServerConnectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @first = ServerConnection.create!(name: "First", provider: :jellyfin, base_url: "https://one.example.com", username: "bruno", password: "secret", user: users(:one))
    @second = ServerConnection.create!(name: "Second", provider: :jellyfin, base_url: "https://two.example.com", username: "bruno", password: "secret", user: users(:one))
  end

  test "selecting a connection persists the preference" do
    patch active_server_connection_url, params: { server_connection_id: @second.id }

    assert_redirected_to root_url
    assert_equal @second, users(:one).reload.preferred_server_connection
  end
end
