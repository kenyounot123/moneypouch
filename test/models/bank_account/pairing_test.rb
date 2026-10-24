require "test_helper"

class BankAccount::PairingTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 6, 18)
    @user = users(:one)
    @access = connect_simplefin
  end

  test "a card payment and the checking withdrawal pair into transfers that no total counts" do
    sync checking: [ row("out", -50_000, 3) ], card: [ row("in", 50_000, 5) ]

    out, incoming = checking_row("out"), card_row("in")
    assert_equal [ incoming, out ], [ out.transfer_partner, incoming.transfer_partner ]
    assert_equal [ true, true ], [ out.linked_transaction.transfer?, incoming.linked_transaction.transfer? ]
    assert_equal [ 550, 200_000, 199_450 ], [ @user.transactions.spent, @user.transactions.income, @user.transactions.net ]
  end

  test "rows arriving in different syncs still pair" do
    activate(@access, report: report(checking: [ row("out", -50_000, 3) ]))
    assert_not checking_row("out").paired?

    sync_again(@access, report: report(card: [ row("in", 50_000, 4) ]))

    assert_equal checking_row("out"), card_row("in").transfer_partner
    assert_equal [ true, true ], [ checking_row("out"), card_row("in") ].map { |bank_row| bank_row.linked_transaction.transfer? }
  end

  test "money out of the card pairs with money into checking the same way" do
    sync checking: [ row("in", 20_000, 4) ], card: [ row("out", -20_000, 4) ]

    assert_equal card_row("out"), checking_row("in").transfer_partner
  end

  test "the same amount in one account never pairs" do
    sync checking: [ row("out", -5_000, 3), row("back", 5_000, 3) ]

    assert_not_paired checking_row("out"), checking_row("back")
  end

  test "two rows of the same sign never pair" do
    sync checking: [ row("one", -5_000, 3) ], card: [ row("two", -5_000, 3) ]

    assert_not_paired checking_row("one"), card_row("two")
  end

  test "a different amount never pairs" do
    sync checking: [ row("out", -5_000, 3) ], card: [ row("in", 5_001, 3) ]

    assert_not_paired checking_row("out"), card_row("in")
  end

  test "rows more than five days apart never pair, and exactly five do" do
    sync checking: [ row("far", -5_000, 1), row("near", -6_000, 1) ], card: [ row("far-in", 5_000, 7), row("near-in", 6_000, 6) ]

    assert_not_paired checking_row("far"), card_row("far-in")
    assert_equal card_row("near-in"), checking_row("near").transfer_partner
  end

  test "another user's row never pairs" do
    elsewhere = connect_simplefin(users(:two))
    activate(elsewhere, [ "Demo Checking" ], report: report(checking: [ row("out", -5_000, 3) ]))
    sync card: [ row("in", 5_000, 3) ]

    assert_not_paired BankTransaction.find_by!(external_id: "out"), card_row("in")
  end

  test "a row matched to something the user typed neither pairs nor is paired" do
    @user.transactions.create!(name: "Payment", amount_in_cents: -5_000, occurred_on: "2026-10-03")
    sync checking: [ row("out", -5_000, 3) ], card: [ row("in", 5_000, 3) ]

    assert checking_row("out").matched?
    assert_not_paired checking_row("out"), card_row("in")

    @user.transactions.create!(name: "Refund", amount_in_cents: 7_000, occurred_on: "2026-10-03")
    sync_again @access, report: report(checking: [ row("out-2", -7_000, 3) ], card: [ row("in-2", 7_000, 3) ])

    assert card_row("in-2").matched?
    assert_not_paired checking_row("out-2"), card_row("in-2")
  end

  test "a partner the user discarded never pairs" do
    sync checking: [ row("out", -5_000, 3) ]
    checking_row("out").linked_transaction.discard
    sync_again @access, report: report(card: [ row("in", 5_000, 3) ])

    assert_not_paired checking_row("out"), card_row("in")
  end

  test "a partner that already has a category never pairs" do
    sync checking: [ row("out", -5_000, 3) ]
    checking_row("out").linked_transaction.update!(category: categories(:food))
    sync_again @access, report: report(card: [ row("in", 5_000, 3) ])

    assert_not_paired checking_row("out"), card_row("in")
    assert_equal [ true, false ], [ checking_row("out").linked_transaction.category.present?, card_row("in").linked_transaction.transfer? ]
  end

  test "a partner that is already a transfer never pairs" do
    sync checking: [ row("out", -5_000, 3) ]
    checking_row("out").linked_transaction.categorize(Transaction::Categorization.transfer)
    sync_again @access, report: report(card: [ row("in", 5_000, 3) ])

    assert_not_paired checking_row("out"), card_row("in")
    assert_not card_row("in").linked_transaction.transfer?
  end

  test "a partner that is already paired is not taken again" do
    sync checking: [ row("out", -5_000, 3) ], card: [ row("in", 5_000, 3) ]
    sync_again @access, report: report(card: [ row("second", 5_000, 3) ])

    assert_equal card_row("in"), checking_row("out").transfer_partner
    assert_not card_row("second").paired?
  end

  test "the closest date wins, then each partner is used once" do
    sync card: [ row("day1", 5_000, 1), row("day4", 5_000, 4) ],
      checking: [ row("first", -5_000, 3), row("second", -5_000, 3), row("third", -5_000, 3) ]

    assert_equal [ card_row("day4"), card_row("day1") ], [ checking_row("first").transfer_partner, checking_row("second").transfer_partner ]
    assert_not checking_row("third").paired?
    assert_equal [ true, true, true, true, false ], %w[ day1 day4 first second third ].map { |id| bank_row(id).linked_transaction.transfer? }
  end

  test "with the dates tied, the lower id wins" do
    sync checking: [ row("early", -5_000, 3), row("late", -5_000, 3) ], card: [ row("in", 5_000, 3) ]

    assert_equal checking_row("early"), card_row("in").transfer_partner
    assert_not checking_row("late").paired?
  end

  test "a rule on the new row's name wins over pairing" do
    groceries = @user.categories.create!(name: "Groceries")
    @user.rules.create!(name: "Payment", name_key: "payment", category: groceries)
    sync checking: [ row("out", -5_000, 3, "Rent") ], card: [ row("in", 5_000, 3, "Payment") ]

    assert_not_paired checking_row("out"), card_row("in")
    assert_equal [ groceries, false ], card_row("in").linked_transaction.then { |transaction| [ transaction.category, transaction.transfer? ] }
    assert_not checking_row("out").linked_transaction.transfer?
  end

  test "pairing beats the category the same name had last time" do
    @user.transactions.create!(name: "Payment", amount_in_cents: -1_000, occurred_on: "2026-09-20", category: categories(:food))
    sync card: [ row("in", 5_000, 3, "Card credit") ], checking: [ row("out", -5_000, 3, "Payment") ]

    assert_equal [ true, nil ], checking_row("out").linked_transaction.then { |transaction| [ transaction.transfer?, transaction.category ] }
    assert_equal card_row("in"), checking_row("out").transfer_partner
  end

  test "a name seen before still takes its last category when there is no partner" do
    @user.transactions.create!(name: "Payment", amount_in_cents: -1_000, occurred_on: "2026-09-20", category: categories(:food))
    sync card: [ row("in", 5_000, 3, "Payment") ]

    assert_equal categories(:food), card_row("in").linked_transaction.category
  end

  test "choosing a category on one side dissolves the pair and frees the other to be categorized" do
    sync checking: [ row("out", -5_000, 3) ], card: [ row("in", 5_000, 3) ]
    checking = checking_row("out").linked_transaction

    checking.categorize(Transaction::Categorization.new(category: categories(:food)))

    assert_equal [ nil, nil ], [ checking_row("out").reload.transfer_partner, card_row("in").reload.transfer_partner ]
    assert_equal categories(:food), checking.reload.category
    partner = card_row("in").linked_transaction
    assert_equal [ false, true ], [ partner.transfer?, partner.needs_category? ]
  end

  test "choosing transfer again on a paired row keeps the pair" do
    sync checking: [ row("out", -5_000, 3) ], card: [ row("in", 5_000, 3) ]

    checking_row("out").linked_transaction.categorize(Transaction::Categorization.transfer)

    assert_equal card_row("in"), checking_row("out").reload.transfer_partner
    assert card_row("in").linked_transaction.transfer?
  end

  test "a freed partner can pair again with a later row" do
    sync checking: [ row("out", -5_000, 3) ], card: [ row("in", 5_000, 3) ]
    checking_row("out").linked_transaction.categorize(Transaction::Categorization.new(category: categories(:food)))
    sync_again @access, report: report(checking: [ row("again", -5_000, 4) ])

    assert_equal card_row("in"), checking_row("again").transfer_partner
  end

  test "no rule is offered for a paired row" do
    sync checking: [ row("out", -5_000, 3) ], card: [ row("in", 5_000, 3) ]
    sync_again @access, report: report(card: [ row("lone", 900, 3) ])
    card_row("lone").linked_transaction.categorize(Transaction::Categorization.new(category: categories(:food)))

    assert card_row("in").linked_transaction.paired?
    assert_not card_row("in").linked_transaction.offers_rule?
    assert card_row("lone").linked_transaction.offers_rule?
  end

  test "deleting a bank account leaves its partner unlinked, not dangling" do
    sync checking: [ row("out", -5_000, 3) ], card: [ row("in", 5_000, 3) ]

    BankAccount.find(card_row("in").bank_account_id).destroy!

    assert_nil checking_row("out").reload.transfer_partner_id
  end

  private
    CHECKING = "Demo Checking"
    CARD = "Demo Savings"

    def row(id, cents, day, name = "Payment")
      { "id" => id, "posted" => Time.utc(2026, 10, day, 18).to_i, "amount" => format("%.2f", cents / 100.0), "description" => name }
    end

    def report(checking: [], card: [])
      simplefin_report.tap do |report|
        demo_account(report, CHECKING)["transactions"] = checking
        demo_account(report, CARD)["transactions"] = card
      end
    end

    def sync(checking: [], card: [])
      activate(@access, [ CHECKING, CARD ], report: report(checking:, card:))
    end

    def bank_row(external_id)
      @user.bank_transactions.find_by!(external_id:)
    end

    def checking_row(external_id)
      bank_row(external_id).tap { |bank_row| assert_equal CHECKING, bank_row.bank_account.external_id }
    end

    def card_row(external_id)
      bank_row(external_id).tap { |bank_row| assert_equal CARD, bank_row.bank_account.external_id }
    end

    def assert_not_paired(*bank_rows)
      assert_equal [ false ] * bank_rows.size, bank_rows.map { |bank_row| bank_row.reload.paired? }
    end
end
