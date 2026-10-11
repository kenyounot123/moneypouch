class Simplefin::Review
  def initialize(syncs)
    @syncs = syncs.unreviewed
  end

  def pending?
    @syncs.imported_transactions.exists?
  end

  def count
    transactions.size
  end

  def needing_category
    transactions.select(&:needs_category?)
  end

  def categorized
    transactions.select(&:category)
  end

  def transfers
    transactions.select(&:transfer?)
  end

  def complete
    @syncs.update_all(reviewed_at: Time.current)
  end

  private
    def transactions
      @transactions ||= @syncs.imported_transactions.listed.includes(bank_transaction: :bank_account).to_a
    end
end
