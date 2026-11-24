class Simplefin::Review
  DUPLICATES = "duplicates"
  TRANSACTION_LISTS = %w[ needing_category categorized transfers ].freeze
  LISTS = [ DUPLICATES, *TRANSACTION_LISTS ].freeze

  attr_reader :duplicates

  def initialize(syncs, duplicates:)
    @syncs = syncs
    @duplicates = duplicates
  end

  def pending?
    needing_category.exists? || completable? || duplicates.present?
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
      LISTS.find { |list| size_of(list).positive? } || TRANSACTION_LISTS.first
    end
  end

  def size_of(list)
    if list == DUPLICATES
      duplicates.size
    else
      transactions_in(list).count
    end
  end

  def transactions_in(list, including: nil)
    if TRANSACTION_LISTS.include?(list)
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
