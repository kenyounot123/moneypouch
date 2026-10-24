class Categories::MergesController < ApplicationController
  def create
    category = Current.user.categories.find(params.expect(:category_id))
    category.merge_into(Current.user.categories.where.not(id: category.id).find(params.expect(:into)))
    redirect_to categories_path, status: :see_other
  end
end
