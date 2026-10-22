class Transactions::ExclusionsController < ApplicationController
  before_action :set_transaction

  def create
    @transaction.exclude
    redirect_back_or_to root_path, status: :see_other
  end

  def destroy
    @transaction.include_in_totals
    redirect_back_or_to root_path, status: :see_other
  end

  private
    def set_transaction
      @transaction = Current.user.transactions.find(params.expect(:transaction_id))
    end
end
