class Simplefin::SyncsController < ApplicationController
  def create
    access = Current.user.simplefin_access

    if access.nil?
      raise ActiveRecord::RecordNotFound
    end

    if access.syncable?
      access.sync_later
    end

    redirect_to settings_path, status: :see_other
  end
end
