class Simplefin::ReviewsController < ApplicationController
  before_action :set_review

  def show
    @list = @review.list_named(params[:show])
    set_page_and_extract_portion_from @review.transactions_in(@list), per_page: 50
    @rules = Current.user.rules.latest.with_row_counts
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
