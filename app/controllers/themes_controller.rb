class ThemesController < ApplicationController
  def update
    Current.user.choose_theme(params.expect(:theme))
    redirect_back_or_to root_path
  end
end
