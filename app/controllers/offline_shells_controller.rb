class OfflineShellsController < ApplicationController
  def show
    @offline_shell = true
    render "offline_downloads/index"
  end
end
