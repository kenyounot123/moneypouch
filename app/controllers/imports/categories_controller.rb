class Imports::CategoriesController < ApplicationController
  include ImportScoped

  def edit
    @category_names = Current.user.categories.alphabetically.pluck(:name)
  end

  def update
    @import.choose_categories(categories_params[:categories])
    redirect_to edit_import_categories_path(@import), status: :see_other
  end

  private
    def categories_params
      params.expect(import: [ categories: [ [ :word, :name ] ] ])
    end
end
