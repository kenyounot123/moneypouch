class GetStartedController < ApplicationController
  def destroy
    Current.user.hide_get_started
    redirect_back_or_to root_path, status: :see_other
  end
end
