class Simplefin::SyncsController < ApplicationController
  include SimplefinAccessScoped

  def create
    @access.sync_later
    redirect_to root_path, status: :see_other
  end
end
