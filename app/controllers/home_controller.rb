class HomeController < ApplicationController
  def index; end

  def content
    @server_connection = current_server_connection
    return render :no_server unless @server_connection

    @result = ServerConnections::FetchCachedHomeContent.new(
      @server_connection,
      access_token: current_access_token,
      user: current_user
    ).call
    @recommendation_collections = current_user.recommendation_collections.where(server_connection: @server_connection).includes(:recommendation_tracks, :server_connection).order(generated_at: :desc).to_a.uniq(&:strategy) if @result.success?
    store_access_token if @result.success?
  end

  private

  def store_access_token
    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(@server_connection.id.to_s => @result.access_token)
  end

  def current_access_token
    session.dig(:server_access_tokens, @server_connection.id.to_s)
  end
end
