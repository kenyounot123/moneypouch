class Simplefin::ReviewsController < ApplicationController
  before_action :set_review

  def show
    @category_names = Current.user.categories.alphabetically.pluck(:name)
  end

  def update
    @review.complete
    redirect_to root_path, status: :see_other
  end

  private
    def set_review
      access = Current.user.simplefin_access

      if access.nil?
        raise ActiveRecord::RecordNotFound
      end

      @review = access.review
    end
end
