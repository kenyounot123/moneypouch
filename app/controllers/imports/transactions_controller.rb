class Imports::TransactionsController < ApplicationController
  include ImportScoped

  def create
    @import.complete

    if @import.completed?
      redirect_to transactions_path(month: @import.latest_occurred_on.strftime("%Y-%m")), flash: { import_id: @import.id }, status: :see_other
    else
      redirect_to new_import_path, status: :see_other
    end
  end
end
