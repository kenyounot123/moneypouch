class Simplefin::Reviews::CompletionsController < ApplicationController
  include SimplefinAccessScoped

  def create
    @access.review.complete
    redirect_to root_path, status: :see_other
  end
end
