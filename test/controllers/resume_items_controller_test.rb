require "test_helper"

class ResumeItemsControllerTest < ActionDispatch::IntegrationTest
  class FakeClient
    def report_playback(**)
      Integrations::Jellyfin::PlaybackReportResponseData.new(access_token: "token")
    end
  end

  setup do
    @server_connection = ServerConnection.create!(
      name: "Resume server",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "resets the saved playback position" do
    client_class = Integrations::Jellyfin::Client
    original_new = client_class.method(:new)
    client_class.define_singleton_method(:new) { |**_attributes| FakeClient.new }

    post reset_resume_server_connection_url(@server_connection, item_id: "podcast-id")

    assert_response :no_content
  ensure
    client_class.define_singleton_method(:new, original_new)
  end
end
