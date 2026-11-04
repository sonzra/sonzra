class PlayerPreferencesController < ApplicationController
  def update
    updated = player_preferences.dup
    if params.key?(:radio_enabled)
      updated["radio_enabled"] = ActiveModel::Type::Boolean.new.cast(params[:radio_enabled])
    end
    if params.key?(:preload_on_wifi_only)
      updated["preload_on_wifi_only"] = ActiveModel::Type::Boolean.new.cast(params[:preload_on_wifi_only])
    end
    session[:player_preferences] = updated
    head :no_content
  end

  private

  def player_preferences
    session.fetch(:player_preferences, {})
  end
end
