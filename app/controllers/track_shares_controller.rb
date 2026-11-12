class TrackSharesController < ApplicationController
  def create
    recipient_id = track_share_params[:recipient_id]
    result = Notifications::DeliverTrackShare.call(
      sender: current_user,
      recipient_id: recipient_id,
      params: track_share_params
    )

    if result.success?
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, notice: "Track shared successfully." }
        format.json { render json: { success: true, notification: result.notification.as_json(methods: %i[recipient_id sender_id]) }, status: :created }
        format.turbo_stream { head :created }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: result.error, status: :unprocessable_entity }
        format.json { render json: { success: false, error: result.error }, status: :unprocessable_entity }
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end

  private

  def track_share_params
    raw_params = params[:track_share].presence || params
    raw_params.permit(:recipient_id, :item_id, :title, :artist, :album, :artwork_item_id, :media_server_id, :server_connection_id, :note)
  end
end
