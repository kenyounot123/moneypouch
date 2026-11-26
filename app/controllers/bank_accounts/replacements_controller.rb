class BankAccounts::ReplacementsController < ApplicationController
  unavailable_in_demo

  def create
    bank_account = Current.user.bank_accounts.missing.joins(:simplefin_access).merge(Simplefin::Access.active).find(params.expect(:bank_account_id))

    if bank_account.replacement_for(params[:replacement_id])
      bank_account.carry_on_with_replacement(params[:replacement_id])
      redirect_to settings_path, status: :see_other
    else
      head :not_found
    end
  end
end
