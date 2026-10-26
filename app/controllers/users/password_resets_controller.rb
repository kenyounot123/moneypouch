class Users::PasswordResetsController < ApplicationController
  before_action :require_owner
  before_action :set_user

  def create
    flash[:reset_username] = @user.username
    flash[:reset_link] = edit_password_url(@user.password_reset_token)
    redirect_to settings_path
  end

  private
    def require_owner
      head :forbidden unless Current.user.owner?
    end

    def set_user
      @user = User.find(params[:user_id])
      head :forbidden if @user == Current.user
    end
end
