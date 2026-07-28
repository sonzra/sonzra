require "test_helper"

class Integrations::Jellyfin::ClientTest < ActiveSupport::TestCase
  class FakeHttp
    attr_reader :last_request

    def initialize(response)
      @response = response
    end

    def start(...)
      yield self
    end

    def request(request)
      @last_request = request
      @response
    end
  end

  test "authenticates with the server credentials" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = { User: { Name: "Bruno" } }.to_json
    http = FakeHttp.new(response)

    user_name = Integrations::Jellyfin::Client.new(
      base_url: "https://example.com/jellyfin",
      username: "bruno",
      password: "secret",
      http: http
    ).authenticate

    assert_equal "Bruno", user_name
    assert_equal "/jellyfin/Users/AuthenticateByName", http.last_request.path
    assert_equal({ "Username" => "bruno", "Pw" => "secret" }, JSON.parse(http.last_request.body))
  end

  test "raises an authentication error for rejected credentials" do
    response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
    http = FakeHttp.new(response)
    client = Integrations::Jellyfin::Client.new(
      base_url: "https://example.com",
      username: "bruno",
      password: "wrong",
      http: http
    )

    assert_raises(Integrations::Jellyfin::Client::AuthenticationError) { client.authenticate }
  end
end
