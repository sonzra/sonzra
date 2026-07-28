module ServerConnections
  FetchLibraryCollectionResultData = Data.define(:items, :total, :access_token, :message) do
    def success?
      message.nil?
    end
  end
end
