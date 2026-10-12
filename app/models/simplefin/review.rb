class Simplefin::Review
  LISTS = %w[ needing_category categorized transfers ].freeze

  def initialize(syncs)
    @syncs = syncs.unreviewed
  end

  def pending?
    @syncs.imported_transactions.exists?
  end

  def count
    transactions.count
  end

  def needing_category
    transactions.needing_category
  end

  def categorized
    transactions.categorized
  end

  def transfers
    transactions.transfers
  end

  def list_named(name)
    if LISTS.include?(name)
      name
    else
      LISTS.find { |list| transactions_in(list).exists? } || LISTS.first
    end
  end

  def transactions_in(list)
    if LISTS.include?(list)
      public_send(list)
    else
      raise ArgumentError, "no #{list} list in a review"
    end
  end

  def complete
    @syncs.update_all(reviewed_at: Time.current)
  end

  private
    def transactions
      @syncs.imported_transactions.listed.includes(bank_transaction: :bank_account)
    end
end
