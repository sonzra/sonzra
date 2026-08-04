class PlayerPreferencesController < ApplicationController
  def update
    session[:player_preferences] = player_preferences.merge("radio_enabled" => ActiveModel::Type::Boolean.new.cast(params[:radio_enabled]))
    head :no_content
  end

  private

  def player_preferences
    session.fetch(:player_preferences, {})
  end
end
