class Imports::TransactionsController < ApplicationController
  include ImportScoped

  # Lands on the newest month the file added to, since a history import may end long before this month.
  def create
    @import.complete

    if @import.completed?
      redirect_to transactions_path(month: @import.latest_occurred_on.strftime("%Y-%m")), flash: { import_id: @import.id }, status: :see_other
    else
      redirect_to new_import_path, status: :see_other
    end
  end
end
