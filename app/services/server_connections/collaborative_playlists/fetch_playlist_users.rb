# frozen_string_literal: true

module ServerConnections
  module CollaborativePlaylists
    class FetchPlaylistUsers
      def initialize(server_connection, playlist_id:, client: nil)
        @server_connection = server_connection
        @playlist_id = playlist_id
        @client = client
      end

      def call
        return failure("Provider does not support collaborative playlists") unless client.supports?(Integrations::Capabilities::COLLABORATIVE_PLAYLISTS)

        users = client.playlist_users(@playlist_id)
        CollaborativePlaylistResultData.new(success: true, users: users, message: nil)
      rescue Integrations::Error => error
        failure(error.message)
      end

      private

      def client
        @client ||= Integrations::Client.for(@server_connection)
      end

      def failure(message)
        CollaborativePlaylistResultData.new(success: false, users: nil, message: message)
      end
    end
  end
end
