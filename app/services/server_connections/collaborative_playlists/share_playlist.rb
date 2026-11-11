# frozen_string_literal: true

module ServerConnections
  module CollaborativePlaylists
    class SharePlaylist
      def initialize(server_connection, target_connection, playlist_id:, can_edit: true, client: nil, target_client: nil)
        @server_connection = server_connection
        @target_connection = target_connection
        @playlist_id = playlist_id
        @can_edit = can_edit
        @client = client
        @target_client = target_client
      end

      def call
        return failure("Provider does not support collaborative playlists") unless client.supports?(Integrations::Capabilities::COLLABORATIVE_PLAYLISTS)
        return failure("Target connection is missing") if @target_connection.nil?
        return failure("Target connection is not on the same media server") unless @target_connection.media_server_id == @server_connection.media_server_id

        remote_target_id = @target_connection.remote_user_id.presence || resolve_remote_user_id(@target_connection)
        return failure("Unable to resolve remote user account") if remote_target_id.blank?

        client.share_playlist(playlist_id: @playlist_id, user_id: remote_target_id, can_edit: @can_edit)
        CollaborativePlaylistResultData.new(success: true, users: nil, message: nil)
      rescue Integrations::Error => error
        failure(error.message)
      end

      private

      def client
        @client ||= Integrations::Client.for(@server_connection)
      end

      def resolve_remote_user_id(connection)
        target_client = @target_client || Integrations::Client.for(connection)
        user_id = target_client.resolved_user_id
        if user_id.blank? && target_client.respond_to?(:authenticate)
          target_client.authenticate
          user_id = target_client.resolved_user_id
        end
        connection.update_column(:remote_user_id, user_id) if user_id.present? && connection.persisted?
        user_id
      rescue Integrations::Error
        nil
      end

      def failure(message)
        CollaborativePlaylistResultData.new(success: false, users: nil, message: message)
      end
    end
  end
end
