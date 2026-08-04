module ServerConnections
  FetchRadioTracksResultData = Data.define(:items, :access_token, :message) do
    def success?
      message.nil?
    end
  end
end
