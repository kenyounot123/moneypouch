class Simplefin::SyncsController < ApplicationController
  def create
    access = Current.user.simplefin_access or raise ActiveRecord::RecordNotFound

    if access.syncable?
      access.sync_later
    end

    redirect_to settings_path, status: :see_other
  end
end
