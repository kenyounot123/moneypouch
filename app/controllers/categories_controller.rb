class CategoriesController < ApplicationController
  before_action :set_category, only: %i[ update destroy ]

  def index
    @categories = Current.user.categories.alphabetically
    @usage = Category::Usage.new(Current.user, Period.new("month", today: Date.current))
  end

  def update
    if @category.revise(params.expect(category: [ :name, :income ]))
      redirect_to categories_path, status: :see_other
    else
      redirect_to categories_path, alert: @category.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    @category.remove
    redirect_to categories_path, status: :see_other
  end

  private
    def set_category
      @category = Current.user.categories.find(params.expect(:id))
    end
end
