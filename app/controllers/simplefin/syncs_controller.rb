class Simplefin::SyncsController < ApplicationController
  unavailable_in_demo

  include SimplefinAccessScoped

  def create
    @access.sync_later
    redirect_to root_path, status: :see_other
  end
end
