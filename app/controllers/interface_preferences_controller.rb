class InterfacePreferencesController < ApplicationController
  def update
    variant = params[:ui_variant].to_s

    unless User::UI_VARIANTS.include?(variant)
      head :unprocessable_entity
      return
    end

    current_user.update!(ui_variant: variant)
    redirect_back fallback_location: root_path, notice: variant == "redesign" ? "The Sonzra redesign is on." : "You are using the classic Sonzra interface."
  end
end
