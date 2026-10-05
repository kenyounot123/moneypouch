class VouchersController < ApplicationController
  def show
    @voucher = Voucher.new(params[:shorthand], user: Current.user, today: Date.current, complete: params[:complete] == "1")
  end
end
