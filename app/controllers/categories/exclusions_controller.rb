class Categories::ExclusionsController < ApplicationController
  before_action :set_category

  def create
    @category.exclude
    redirect_back_or_to categories_path, status: :see_other
  end

  def destroy
    @category.include_in_totals
    redirect_back_or_to categories_path, status: :see_other
  end

  private
    def set_category
      @category = Current.user.categories.changeable.find(params.expect(:category_id))
    end
end
