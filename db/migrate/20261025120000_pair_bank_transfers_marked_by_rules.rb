require_relative "20261023120000_pair_bank_transfers" unless defined?(PairBankTransfers)

# The first pass skipped rows a rule had already marked as transfers, which left their other halves uncategorized.
class PairBankTransfersMarkedByRules < ActiveRecord::Migration[8.1]
  def up
    PairBankTransfers.new.pair_existing_rows
  end

  def down
  end
end
