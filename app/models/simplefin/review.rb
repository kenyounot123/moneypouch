class Simplefin::Review
  LISTS = %w[ needing_category categorized transfers ].freeze

  def initialize(syncs)
    @syncs = syncs
  end

  def pending?
    needing_category.exists? || completable?
  end

  def completable?
    @syncs.unreviewed.added_transactions.exists?
  end

  def needing_category
    transactions(@syncs).needing_category
  end

  def categorized
    transactions(@syncs.unreviewed).categorized
  end

  def transfers
    transactions(@syncs.unreviewed).transfers
  end

  def list_named(name)
    if LISTS.include?(name)
      name
    else
      LISTS.find { |list| transactions_in(list).exists? } || LISTS.first
    end
  end

  def transactions_in(list, including: nil)
    if LISTS.include?(list)
      public_send(list).or(transactions(@syncs).where(id: including))
    else
      raise ArgumentError, "no #{list} list in a review"
    end
  end

  def complete
    @syncs.unreviewed.update_all(reviewed_at: Time.current)
  end

  private
    def transactions(syncs)
      syncs.added_transactions.listed.includes(bank_transaction: [ :bank_account, { transfer_partner: :bank_account } ])
    end
end
