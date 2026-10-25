require "test_helper"
require Rails.root.join("db/migrate/20261023120000_pair_bank_transfers")

class PairBankTransfersTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    @user = users(:one)
    @access = connect_simplefin
    @checking = @access.bank_accounts.find_by!(external_id: "Demo Checking")
    @card = @access.bank_accounts.find_by!(external_id: "Demo Savings")
    @sync = @access.syncs.create!
  end

  test "pairs a payment with its other half and marks both as transfers" do
    out = add(@checking, -50_000, 3)
    incoming = add(@card, 50_000, 5)

    pair_existing_rows

    assert_equal [ incoming.id, out.id ], [ out.reload.transfer_partner_id, incoming.reload.transfer_partner_id ]
    assert_equal [ true, true ], [ out.linked_transaction.transfer?, incoming.linked_transaction.transfer? ]
  end

  test "with several candidates only the mutual best pair is made" do
    early_out = add(@checking, -5_000, 1)
    late_out = add(@checking, -5_000, 3)
    incoming = add(@card, 5_000, 3)

    pair_existing_rows

    assert_equal incoming.id, late_out.reload.transfer_partner_id
    assert_equal late_out.id, incoming.reload.transfer_partner_id
    assert_nil early_out.reload.transfer_partner_id
    assert_not early_out.linked_transaction.transfer?
  end

  test "equal gaps go to the lower id" do
    first = add(@checking, -5_000, 2)
    second = add(@checking, -5_000, 2)
    incoming = add(@card, 5_000, 3)

    pair_existing_rows

    assert_equal first.id, incoming.reload.transfer_partner_id
    assert_nil second.reload.transfer_partner_id
  end

  test "rows pair across the whole set, each used once" do
    outs = [ add(@checking, -1_000, 1), add(@checking, -2_000, 1) ]
    ins = [ add(@card, 2_000, 2), add(@card, 1_000, 2) ]

    pair_existing_rows

    assert_equal [ ins[1].id, ins[0].id ], outs.map { |bank_row| bank_row.reload.transfer_partner_id }
  end

  test "running it again changes nothing" do
    add(@checking, -50_000, 3)
    add(@card, 50_000, 3)
    add(@checking, -7_000, 1)
    add(@checking, -7_000, 3)
    add(@card, 7_000, 3)

    pair_existing_rows
    snapshot = BankTransaction.order(:id).pluck(:id, :transfer_partner_id)
    pair_existing_rows

    assert_equal snapshot, BankTransaction.order(:id).pluck(:id, :transfer_partner_id)
    assert_equal 4, snapshot.count { |_, partner| partner }
    assert_equal 4, Transaction.transfers.count
  end

  test "a row a rule already marked as a transfer pairs too" do
    out = add(@checking, -5_000, 3)
    incoming = add(@card, 5_000, 3, transfer: true)

    pair_existing_rows

    assert_equal [ incoming.id, out.id ], [ out.reload.transfer_partner_id, incoming.reload.transfer_partner_id ]
    assert out.linked_transaction.transfer?
  end

  test "rows the sync would not pair are left alone" do
    other = connect_simplefin(users(:two))
    stranger = other.bank_accounts.find_by!(external_id: "Demo Checking")
    out = add(@checking, -5_000, 3)
    ineligible = [
      add(@checking, 5_000, 3),
      add(@card, 5_000, 3, matched: true),
      add(@card, 5_000, 3, discarded_at: Time.current),
      add(@card, 5_000, 3, category: categories(:food)),
      add(@card, 5_000, 9),
      add(@card, 5_000, 3, currency: "EUR"),
      add(stranger, 5_000, 3, owner: users(:two)),
      add(@card, 4_999, 3)
    ]
    zeros = [ add(@checking, 0, 3), add(@card, 0, 3) ]

    assert_no_difference -> { BankTransaction.where.not(transfer_partner_id: nil).count } do
      pair_existing_rows
    end

    assert_equal [ out, *ineligible, *zeros ].map { |bank_row| bank_row.linked_transaction.transfer? },
      [ false, false, false, false, false, false, false, false, false, false, false ]
  end

  private
    def pair_existing_rows
      migration = PairBankTransfers.new
      migration.suppress_messages { migration.pair_existing_rows }
    end

    def add(bank_account, cents, day, owner: @user, matched: false, currency: "USD", **attributes)
      transaction = owner.transactions.create!(name: "Payment", amount_in_cents: cents, occurred_on: Date.new(2026, 10, day), currency:, **attributes)
      bank_account.bank_transactions.create!(simplefin_sync: @sync, transaction_id: transaction.id, matched:, external_id: SecureRandom.hex(4),
        amount_in_cents: cents, occurred_on: transaction.occurred_on, description: "Payment", name_key: "payment")
    end
end
