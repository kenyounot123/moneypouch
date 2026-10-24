class CategoriesController < ApplicationController
  before_action :set_category, only: %i[ update destroy ]

  def index
    @categories = Current.user.categories.alphabetically
    @usage = Category::Usage.new(Current.user, span)
  end

  def show
    @category = Current.user.categories.find(params.expect(:id))
    @usage = Category::Usage.new(Current.user, span)
    @listing = Transaction::Listing.new(Current.user, period: span, filters: { category: @category.id }, before:)
    @categories = Current.user.categories.alphabetically
  end

  def update
    if @category.revise(params.expect(category: [ :name ]))
      redirect_back_or_to categories_path, status: :see_other
    else
      redirect_back_or_to categories_path, alert: @category.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    @category.remove
    redirect_to categories_path, status: :see_other
  end

  private
    def set_category
      @category = Current.user.categories.changeable.find(params.expect(:id))
    end

    def span
      @span ||= Category::Span.from(params, today: Date.current)
    end

    def before
      Date.iso8601(params[:before].to_s)
    rescue Date::Error
      nil
    end
end
