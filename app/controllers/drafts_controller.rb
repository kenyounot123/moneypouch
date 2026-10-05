class DraftsController < ApplicationController
  def show
    @draft = Transaction::Draft.parse(params[:line], user: Current.user, today: Date.current)
  end
end
