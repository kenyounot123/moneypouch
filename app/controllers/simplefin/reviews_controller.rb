class Simplefin::ReviewsController < ApplicationController
  before_action :set_review

  def show
    @list = @review.list_named(params[:show])
    categorized_id = flash[:categorized_id]
    set_page_and_extract_portion_from @review.transactions_in(@list, including: categorized_id), per_page: 50
    keep_categorized_for_later_page(categorized_id)
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

    # After a pick Turbo reloads each loaded page frame in turn, so the row's own page has to see the flash too.
    def keep_categorized_for_later_page(id)
      if id && @page.before_last? && @page.records.none? { |transaction| transaction.id == id }
        flash.keep(:categorized_id)
      end
    end
end
