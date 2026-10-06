class DarkThemeController < ApplicationController
  def update
    Current.user.update(background: "dark")
    set_dark_theme_cookie
    redirect_back_or_to root_path
  end

  private
    def set_dark_theme_cookie
      cookies.delete :theme
      cookies.permanent[:theme] = "dark"
    end
end
