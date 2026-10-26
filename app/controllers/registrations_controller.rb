class RegistrationsController < ApplicationController
  def update
    if Current.user.owner?
      Current.user.open_registration(params.expect(:open))
      redirect_back_or_to settings_path
    else
      head :forbidden
    end
  end
end
