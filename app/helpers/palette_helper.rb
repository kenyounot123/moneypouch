module PaletteHelper
  def palette_voucher
    Voucher.new(flash[:shorthand], user: Current.user, today: Date.current)
  end

  def palette_category_names
    Current.user.categories.alphabetically.pluck(:name)
  end

  def added_transaction
    Current.user.transactions.find_by(id: flash[:added_id])
  end
end
