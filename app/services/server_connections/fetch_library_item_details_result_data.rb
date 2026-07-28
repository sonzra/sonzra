module ServerConnections
  FetchLibraryItemDetailsResultData = Data.define(:details, :access_token, :message) do
    def success?
      message.nil?
    end
  end
end
