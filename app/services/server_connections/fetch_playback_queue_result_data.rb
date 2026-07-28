module ServerConnections
  FetchPlaybackQueueResultData = Data.define(:items, :access_token, :message) do
    def success?
      message.nil?
    end
  end
end
