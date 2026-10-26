class AccountsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_account_path, alert: "Try again later." }

  before_action :require_open_registration

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user
      redirect_to first_transaction_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def require_open_registration
      redirect_to new_session_path, alert: "Registration is closed." unless User.registration_open?
    end

    def user_params
      params.expect(user: [ :username, :password ])
    end
end
