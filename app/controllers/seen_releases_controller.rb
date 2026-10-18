class SeenReleasesController < ApplicationController
  def create
    Current.user.see_releases
    redirect_back_or_to root_path, status: :see_other
  end
end
