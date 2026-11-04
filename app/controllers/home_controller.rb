class HomeController < ApplicationController
  def index; end

  def content
    @server_connection = current_server_connection
    return render :no_server unless @server_connection

    @result = ServerConnections::FetchCachedHomeContent.new(
      @server_connection,
      access_token: server_access_token(@server_connection),
      user: current_user,
      device_id: current_device_id
    ).call
    if @result.success?
      clear_connection_alert(@server_connection)
      collections = current_user.recommendation_collections.where(server_connection: @server_connection).includes(:recommendation_tracks, :server_connection).order(generated_at: :desc).to_a.uniq(&:strategy)
      genre_filter = HiddenGenres::Filter.new(current_user, @server_connection)
      @recommendation_collections = collections.reject do |collection|
        collection.strategy == "best_of_genre" && genre_filter.hidden?(collection.title.delete_prefix("Best of ").strip)
      end
    elsif @result.message.to_s.match?(/session expired|401|authentication/i)
      record_connection_alert(@server_connection)
    end
    store_server_access_token(@server_connection, @result.access_token) if @result.success?
  end
end
