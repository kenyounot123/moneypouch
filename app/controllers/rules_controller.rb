class RulesController < ApplicationController
  def destroy
    Current.user.rules.find(params.expect(:id)).destroy
    redirect_back_or_to simplefin_review_path, status: :see_other
  end
end
