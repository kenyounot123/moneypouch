class Simplefin::AccessesController < ApplicationController
  before_action :set_access, only: %i[ edit update destroy ]

  def new
  end

  def create
    Current.user.connect_simplefin(setup_token)
    redirect_to edit_simplefin_access_path, status: :see_other
  rescue Simplefin::TokenRejected, Simplefin::Unavailable => error
    @setup_token, @error = setup_token, error.message
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    @access.activate(account_ids: activate_params[:account_ids], history: activate_params[:history])
    redirect_to settings_path, status: :see_other
  end

  def destroy
    @access.disconnect
    redirect_to settings_path, status: :see_other
  end

  private
    def set_access
      @access = Current.user.simplefin_access or raise ActiveRecord::RecordNotFound
    end

    def setup_token
      params.expect(simplefin_access: [ :setup_token ])[:setup_token]
    end

    def activate_params
      params.expect(simplefin_access: [ :history, account_ids: [] ])
    end
end
