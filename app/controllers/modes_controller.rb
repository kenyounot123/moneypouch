class ModesController < ApplicationController
  def update
    Current.user.choose_mode(params.expect(:mode))
    redirect_back_or_to root_path
  end
end
