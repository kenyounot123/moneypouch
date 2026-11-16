require_relative "20261023120000_pair_bank_transfers" unless defined?(PairBankTransfers)

class PairBankTransfersMarkedByRules < ActiveRecord::Migration[8.1]
  def up
    PairBankTransfers.new.pair_mutual_closest_matches
  end

  def down
  end
end
