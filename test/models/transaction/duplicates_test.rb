require "test_helper"

class Transaction::DuplicatesTest < ActiveSupport::TestCase
  setup do
    travel_to Time.utc(2026, 10, 20, 18)
    @user = users(:one)
    @access = connect_simplefin
  end

  test "offers one bank row of the same amount up to seven days either way, and no further" do
    sync bank_row("first", -1_100, 10), bank_row("second", -1_200, 10), bank_row("third", -1_300, 10), bank_row("fourth", -1_400, 10)
    typed "Seven later", -1_100, 17
    typed "Seven earlier", -1_200, 3
    typed "Eight later", -1_300, 18
    typed "Eight earlier", -1_400, 2

    assert_equal [ [ "Seven earlier", [ "second" ] ], [ "Seven later", [ "first" ] ] ], offered.sort
  end

  test "offers the nearest bank row of the same amount" do
    sync bank_row("far", -1_100, 8), bank_row("near", -1_100, 11)
    typed "Lunch", -1_100, 12

    assert_equal [ [ "Lunch", [ "near" ] ] ], offered
  end

  test "offers two bank rows that add up, across accounts" do
    sync bank_row("checking", -4_820, 9), savings: [ bank_row("savings", -1_737, 10) ]
    typed "Groceries", -6_557, 10

    assert_equal [ [ "Groceries", [ "checking", "savings" ] ] ], offered
  end

  test "offers money in that adds up" do
    sync bank_row("checking", 200_000, 9), savings: [ bank_row("savings", 50_000, 10) ]
    typed "Pay", 250_000, 12

    assert_equal [ [ "Pay", [ "checking", "savings" ] ] ], offered
  end

  test "two bank rows add up only within three days of the typed row and one day of each other" do
    sync bank_row("a1", -1_000, 4), bank_row("a2", -101, 4), bank_row("b1", -2_000, 11), bank_row("b2", -202, 13)
    typed "Four days later", -1_101, 8
    typed "Two days between", -2_202, 12

    assert_empty offered

    typed "Three days later", -1_101, 7

    assert_equal [ [ "Three days later", [ "a1", "a2" ] ] ], offered
  end

  test "two bank rows never add up from opposite directions" do
    sync bank_row("out", -5_000, 10), bank_row("back", 1_000, 10)
    typed "Net", -4_000, 10

    assert_empty offered
  end

  test "a bank row of the whole amount is offered before two that add up" do
    sync bank_row("half", -500, 10), bank_row("other half", -500, 10), bank_row("whole", -1_000, 4)
    typed "Lunch", -1_000, 10

    assert_equal [ [ "Lunch", [ "whole" ] ] ], offered
  end

  test "offers a run of equal rows with one name" do
    sync bank_row("one", -300, 9, "Transit"), bank_row("two", -300, 9, "Transit"), bank_row("three", -300, 10, "Transit")
    typed "Fares", -900, 11

    assert_equal [ [ "Fares", [ "one", "two", "three" ] ] ], offered
  end

  test "refuses three rows with mixed names, mixed amounts, or more than a day between the first and last" do
    sync bank_row("a1", -300, 3, "Transit"), bank_row("a2", -300, 3, "Transit"), bank_row("a3", -300, 3, "Bakery"),
      bank_row("b1", -500, 10, "Cafe"), bank_row("b2", -600, 10, "Cafe"), bank_row("b3", -700, 10, "Cafe"),
      bank_row("c1", -400, 15, "Parking"), bank_row("c2", -400, 16, "Parking"), bank_row("c3", -400, 17, "Parking")
    typed "Mixed names", -900, 3
    typed "Mixed amounts", -1_800, 10
    typed "Spread out", -1_200, 16

    assert_empty offered
  end

  test "two typed rows take the runs side by side" do
    sync(*(1..6).map { |number| bank_row("fare #{number}", -300, 9, "Transit") })
    typed "Monday", -900, 9
    typed "Tuesday", -900, 10

    assert_equal [ [ "Monday", [ "fare 1", "fare 2", "fare 3" ] ], [ "Tuesday", [ "fare 4", "fare 5", "fare 6" ] ] ], offered
  end

  test "one bank row goes to the nearest of two typed rows, and to the other once the first is kept" do
    sync bank_row("lunch", -1_100, 10)
    far = typed("Far", -1_100, 13)
    near = typed("Near", -1_100, 11)

    assert_equal [ [ "Near", [ "lunch" ] ] ], offered

    @user.keep_both(near.id, bank_ids("lunch"))
    assert_equal [ [ "Far", [ "lunch" ] ] ], offered

    @user.merge_duplicate(far.id, bank_ids("lunch"))
    assert_empty offered
    assert_equal [ true, false ], [ near, far ].map { |row| @user.transactions.exists?(row.id) }
  end

  test "with the dates tied, the lower ids win" do
    sync bank_row("first", -1_100, 10), bank_row("second", -1_100, 10)
    typed "One", -1_100, 12
    typed "Two", -1_100, 12

    assert_equal [ [ "One", [ "first" ] ], [ "Two", [ "second" ] ] ], offered
  end

  test "a bank row answered Same transaction is never offered again" do
    sync bank_row("lunch", -1_100, 10)
    @user.merge_duplicate(typed("Lunch", -1_100, 12).id, bank_ids("lunch"))

    typed "Lunch again", -1_100, 12

    assert_empty offered
  end

  test "a run leaves out a fare that another typed row takes" do
    sync(*(1..4).map { |number| bank_row("fare #{number}", -300, 9, "Transit") })
    typed "One fare", -300, 9
    typed "Three fares", -900, 9

    assert_equal [ [ "One fare", [ "fare 1" ] ], [ "Three fares", [ "fare 2", "fare 3", "fare 4" ] ] ], offered
  end

  test "two bank rows are never duplicates of each other" do
    sync bank_row("checking", -1_100, 10), savings: [ bank_row("savings", -1_100, 10) ]

    assert_empty offered
  end

  test "skips the opposite direction, another currency, and zero" do
    sync bank_row("out", -1_100, 10), bank_row("zero", 0, 10), bank_row("dollars", -1_200, 10)
    typed "Refund", 1_100, 10
    typed "Nothing", 0, 10
    typed "Euros", -1_200, 10, currency: "EUR"

    assert_empty offered
  end

  test "skips transfers, excluded rows, and discarded rows on either side" do
    sync bank_row("a", -1_100, 10), bank_row("b", -1_200, 10), bank_row("c", -1_300, 10), bank_row("d", -1_400, 10), bank_row("e", -1_500, 10), bank_row("f", -1_600, 10)
    typed("A", -1_100, 10).categorize(Transaction::Categorization.transfer)
    typed("B", -1_200, 10).exclude
    typed("C", -1_300, 10).discard
    typed "D", -1_400, 10
    typed "E", -1_500, 10
    typed "F", -1_600, 10
    from_bank("d").categorize(Transaction::Categorization.transfer)
    from_bank("e").exclude
    from_bank("f").discard

    assert_empty offered
  end

  test "skips rows the sync already matched" do
    typed "Lunch", -1_100, 10
    sync bank_row("lunch", -1_100, 10)

    typed "Lunch again", -1_100, 10

    assert @user.bank_transactions.find_by!(external_id: "lunch").matched?
    assert_empty offered
  end

  test "never offers another user's rows" do
    sync bank_row("lunch", -1_100, 10)
    users(:two).transactions.create!(name: "Theirs", amount_in_cents: -1_100, occurred_on: "2026-10-10")

    assert_empty offered
    assert_empty users(:two).possible_duplicates.to_a
  end

  test "Same transaction keeps the bank's row and drops the typed one from the totals once" do
    sync bank_row("lunch", -1_100, 10)
    lunch = typed("Lunch", -1_100, 12)

    assert_difference -> { @user.transactions.net }, 1_100 do
      2.times { @user.merge_duplicate(lunch.id, bank_ids("lunch")) }
    end
    assert_equal [ true, false ], [ from_bank("lunch"), lunch ].map { |row| @user.transactions.exists?(row.id) }
  end

  test "Same transaction gives the bank's rows the category and note they lack" do
    sync bank_row("first", -4_820, 10), bank_row("second", -1_737, 10)
    groceries = typed("Groceries", -6_557, 10, category: categories(:food), note: "For the party")

    @user.merge_duplicate(groceries.id, bank_ids("first", "second"))

    assert_equal [ [ "Food", "For the party" ] ] * 2, [ from_bank("first"), from_bank("second") ].map { |row| [ row.category.name, row.note ] }
  end

  test "Same transaction never overwrites the bank row's category or note" do
    sync bank_row("lunch", -1_100, 10)
    eating_out = @user.categories.create!(name: "Eating out")
    from_bank("lunch").update!(category: eating_out, note: "With Sam")
    lunch = typed("Lunch", -1_100, 12, category: categories(:food), note: "Team lunch")

    @user.merge_duplicate(lunch.id, bank_ids("lunch"))

    assert_equal [ eating_out, "With Sam" ], from_bank("lunch").then { |row| [ row.category, row.note ] }
  end

  test "Same transaction with nothing to give leaves the bank row waiting for a category" do
    sync bank_row("lunch", -1_100, 10)
    lunch = typed("Lunch", -1_100, 12)

    @user.merge_duplicate(lunch.id, bank_ids("lunch"))

    assert_equal [ true, nil ], from_bank("lunch").then { |row| [ row.needs_category?, row.note ] }
  end

  test "an answer to rows that changed since does nothing" do
    sync bank_row("edited", -1_100, 10), bank_row("gone", -1_200, 10), bank_row("other", -5_500, 10)
    edited = typed("Edited", -1_100, 12)
    stays = typed("Stays", -1_200, 12)
    edited.update!(amount_in_cents: -1_111)
    from_bank("gone").discard

    assert_no_changes -> { [ @user.transactions.order(:id).pluck(:id), Transaction::DuplicateAnswer.count ] } do
      [ [ edited.id, bank_ids("edited") ], [ stays.id, bank_ids("gone") ], [ stays.id, bank_ids("other") ], [ stays.id, [] ], [ 0, bank_ids("gone") ] ].each do |transaction_id, bank_transaction_ids|
        @user.merge_duplicate(transaction_id, bank_transaction_ids)
        @user.keep_both(transaction_id, bank_transaction_ids)
      end
    end
  end

  test "an answer naming fewer or more bank rows than offered does nothing" do
    sync bank_row("first", -4_820, 10), bank_row("second", -1_737, 10), bank_row("third", -100, 10)
    groceries = typed("Groceries", -6_557, 10)

    assert_no_difference -> { @user.transactions.count } do
      @user.merge_duplicate(groceries.id, bank_ids("first"))
      @user.merge_duplicate(groceries.id, bank_ids("first", "second", "third"))
    end
  end

  test "an answer from another user does nothing" do
    sync bank_row("lunch", -1_100, 10)
    lunch = typed("Lunch", -1_100, 12)

    users(:two).merge_duplicate(lunch.id, bank_ids("lunch"))
    users(:two).keep_both(lunch.id, bank_ids("lunch"))

    assert_equal [ [ "Lunch", [ "lunch" ] ] ], offered
  end

  test "Keep both stays answered after the next sync, and a new bank row is offered" do
    sync bank_row("lunch", -1_100, 10)
    lunch = typed("Lunch", -1_100, 12)

    @user.keep_both(lunch.id, bank_ids("lunch"))
    assert_empty offered

    sync_again @access, report: report([ bank_row("lunch", -1_100, 10) ])
    assert_empty offered

    sync_again @access, report: report([ bank_row("lunch", -1_100, 10), bank_row("later", -1_100, 8) ])
    assert_equal [ [ "Lunch", [ "later" ] ] ], offered
  end

  test "Keep both on rows that add up hides each of those bank rows from the typed row" do
    sync bank_row("first", -4_820, 10), bank_row("second", -1_737, 10)
    groceries = typed("Groceries", -6_557, 10)

    @user.keep_both(groceries.id, bank_ids("first", "second"))

    assert_empty offered
    assert @user.transactions.exists?(groceries.id)
  end

  test "undoing the import forgets its answers and frees the bank rows" do
    sync bank_row("same", -1_100, 10), bank_row("different", -1_200, 10)
    import = import_rows
    @user.merge_duplicate(import.transactions.find_by!(name: "Same").id, bank_ids("same"))
    @user.keep_both(import.transactions.find_by!(name: "Different").id, bank_ids("different"))

    import.undo

    assert_equal 0, Transaction::DuplicateAnswer.count
    import_rows
    assert_equal [ [ "Different", [ "different" ] ], [ "Same", [ "same" ] ] ], offered.sort
  end

  test "a user with answers can be deleted" do
    sync bank_row("same", -1_100, 10), bank_row("different", -1_200, 10)
    @user.merge_duplicate(typed("Same", -1_100, 12).id, bank_ids("same"))
    @user.keep_both(typed("Different", -1_200, 12).id, bank_ids("different"))

    @user.destroy!

    assert_equal 0, Transaction::DuplicateAnswer.count
  end

  test "the database uses each bank row up once" do
    sync bank_row("lunch", -1_100, 10)
    bank_transaction = @user.bank_transactions.sole
    Transaction::DuplicateAnswer.create!(typed_transaction: typed("One", -1_100, 12), bank_transaction:, same: true)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Transaction::DuplicateAnswer.create!(typed_transaction: typed("Two", -1_100, 12), bank_transaction:, same: true)
    end
  end

  test "an answer refreshes the user's open pages once" do
    sync bank_row("first", -4_820, 10), bank_row("second", -1_737, 10)
    groceries = typed("Groceries", -6_557, 10, category: categories(:food), note: "Party")

    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts [ @user, :transactions ], count: 1 do
        @user.merge_duplicate(groceries.id, bank_ids("first", "second"))
      end
    end
  end

  test "reads the same number of times for one entry as for many" do
    sync(*(1..20).map { |number| bank_row("row #{number}", -(1_000 + number), 10) })
    typed "Row 1", -1_001, 12
    import_rows
    one = count_queries { read(@user.possible_duplicates) }
    (2..20).each { |number| typed "Row #{number}", -(1_000 + number), 12 }

    assert_equal [ 20, one ], [ @user.possible_duplicates.size, count_queries { read(@user.possible_duplicates) } ]
  end

  test "counts without loading any entry" do
    sync bank_row("lunch", -1_100, 10)
    typed "Lunch", -1_100, 12

    assert_queries_count(3) { assert_equal [ 1, false ], @user.possible_duplicates.then { |duplicates| [ duplicates.size, duplicates.empty? ] } }
  end

  private
    def bank_row(id, cents, day, name = "Shop")
      { "id" => id, "posted" => Time.utc(2026, 10, day, 18).to_i, "amount" => format("%.2f", cents / 100.0), "description" => name }
    end

    def report(checking, savings: [])
      simplefin_report.tap do |report|
        demo_account(report, "Demo Checking")["transactions"] = checking
        demo_account(report, "Demo Savings")["transactions"] = savings
      end
    end

    def sync(*checking, savings: [])
      activate(@access, report: report(checking, savings:))
    end

    def typed(name, amount_in_cents, day, **attributes)
      @user.transactions.create!(name:, amount_in_cents:, occurred_on: Date.new(2026, 10, day), **attributes)
    end

    def import_rows
      @user.start_import(upload("october.csv", "Date,Name,Amount\n2026-10-10,Same,11.00\n2026-10-10,Different,12.00\n")).tap(&:complete)
    end

    def bank_ids(*external_ids)
      @user.bank_transactions.where(external_id: external_ids).ids
    end

    def from_bank(external_id)
      @user.bank_transactions.find_by!(external_id:).linked_transaction
    end

    def offered
      @user.possible_duplicates.map do |duplicate|
        [ duplicate.typed.name, duplicate.bank_rows.map { |bank_row| bank_row.bank_transaction.external_id } ]
      end
    end

    def read(duplicates)
      duplicates.each { |duplicate| [ duplicate.typed.import&.filename, duplicate.bank_rows.map(&:bank_account_name) ] }
    end

    def count_queries(&)
      count = 0
      ActiveSupport::Notifications.subscribed(->(*) { count += 1 }, "sql.active_record", &)
      count
    end
end
