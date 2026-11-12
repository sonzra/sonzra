# frozen_string_literal: true

module ServerConnections
  module CollaborativePlaylists
    CollaborativePlaylistResultData = Data.define(:success, :users, :message) do
      def success? = success
    end
  end
end
