class PasswordsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :update, with: -> { redirect_to new_session_path, alert: "Try again later." }
  before_action :set_user_by_token

  def edit
  end

  def update
    if @user.reset_password(params[:password], params[:password_confirmation])
      redirect_to new_session_path, notice: "Password changed. Sign in with your new password."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token(params[:token])

      unless @user
        redirect_to new_session_path, alert: "That reset link has expired or was already used."
      end
    end
end
