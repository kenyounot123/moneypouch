class ShortcutsController < ApplicationController
  def update
    Current.user.use_single_key_shortcuts(params.expect(:on))
    redirect_back_or_to settings_path
  end
end
