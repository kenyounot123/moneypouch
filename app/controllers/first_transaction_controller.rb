class FirstTransactionController < ApplicationController
  def show
    if Current.user.transactions.exists?
      flash.keep
      redirect_to root_path
    else
      @voucher = Voucher.new(flash[:shorthand], user: Current.user, today: Date.current)
      @category_names = Current.user.categories.alphabetically.pluck(:name)
    end
  end
end
