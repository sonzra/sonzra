module ServerConnections
  FetchLibraryCollectionResultData = Data.define(:items, :total, :access_token, :message, :has_more) do
    def initialize(items:, total:, access_token:, message: nil, has_more: false)
      super(items:, total:, access_token:, message:, has_more:)
    end

    def success?
      message.nil?
    end
  end
end
