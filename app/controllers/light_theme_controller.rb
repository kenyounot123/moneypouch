class LightThemeController < ApplicationController
  def update
    Current.user.update(background: "light")
    set_light_theme_cookie
    redirect_to root_path
  end

  private
    def set_light_theme_cookie
      cookies.delete :theme
      cookies.permanent[:theme] = "light"
    end
end
