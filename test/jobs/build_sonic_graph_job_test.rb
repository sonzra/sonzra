require "test_helper"

class BuildSonicGraphJobTest < ActiveJob::TestCase
  setup do
    @connection = ServerConnection.create!(
      name: "Library",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "enqueues graph build when ServerConnection is created" do
    assert_enqueued_with(job: BuildSonicGraphJob) do
      ServerConnection.create!(
        name: "New Connection",
        provider: :plex,
        username: "bruno",
        base_url: "https://plex.example.com",
        access_token: "token",
        user: users(:one)
      )
    end
  end

  test "runs builder for specified connection without raising" do
    client = Object.new
    client.define_singleton_method(:supports?) { |_| false }

    original_for = Integrations::Client.method(:for)
    Integrations::Client.define_singleton_method(:for) { |*_args| client }

    begin
      assert_nothing_raised do
        BuildSonicGraphJob.perform_now(@connection.id)
      end
    ensure
      Integrations::Client.define_singleton_method(:for, original_for)
    end
  end

  test "runs builder for all connections when called without arguments" do
    client = Object.new
    client.define_singleton_method(:supports?) { |_| false }

    original_for = Integrations::Client.method(:for)
    Integrations::Client.define_singleton_method(:for) { |*_args| client }

    begin
      assert_nothing_raised do
        BuildSonicGraphJob.perform_now
      end
    ensure
      Integrations::Client.define_singleton_method(:for, original_for)
    end
  end
end
