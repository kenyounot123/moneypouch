require "test_helper"

class ImportsHelperTest < ActionView::TestCase
  include MoneyHelper

  test "every column kind has a title and a place in the field order" do
    assert_equal Import::Columns::KINDS.sort, ImportsHelper::COLUMN_KINDS.keys.sort
    assert_equal (Import::Columns::KINDS - [ "skip" ]).sort, ImportsHelper::FIELD_ORDER.sort
  end

  test "a row names its tab when the file has tabs" do
    assert_equal "2023, row 214", row_place(Import::UnreadableRow.new(tab: "2023", number: 214, name: nil, reason: "there's no amount"))
    assert_equal "Row 12", row_place(Import::UnreadableRow.new(tab: nil, number: 12, name: nil, reason: "there's no amount"))
  end

  test "a new line counts its rows and says refunds and transfers in the plural" do
    assert_equal [ "7 spent", "1 refund", "2 refunds", "3 income", "1 transfer", "2 transfers", "1 excluded", "1,200 spent" ],
      [ [ :spent, 7 ], [ :refund, 1 ], [ :refund, 2 ], [ :income, 3 ], [ :transfer, 1 ], [ :transfer, 2 ], [ :excluded, 1 ], [ :spent, 1_200 ] ].map { |kind, count| tally_line_label(Import::Tally::Line.new(kind:, count:, cents: 0)) }
  end

  test "a row already here says where its match came from" do
    assert_equal "typed in", already_here_source(Transaction.new)
    assert_equal "deleted before", already_here_source(Transaction.new(discarded_at: Time.current))
    assert_equal "from earlier.csv", already_here_source(Transaction.new(import: Import.new(filename: "earlier.csv")))
    assert_equal "from your bank", already_here_source(Transaction.new(bank_transaction: BankTransaction.new))
    assert_equal "from your bank", already_here_source(Transaction.new(bank_transaction: BankTransaction.new, import: Import.new(filename: "earlier.csv")))
    assert_equal "deleted before", already_here_source(Transaction.new(discarded_at: Time.current, bank_transaction: BankTransaction.new))
  end

  test "the Total check says what matched or what the file says instead" do
    assert_equal "Matches the Total row in personal.csv", total_check_sentence(:matches, "personal.csv")
    assert_equal "The Total row in personal.csv says $4,183.06", total_check_sentence(Import::StatedTotal.new(tab: nil, cents: 418_306), "personal.csv")
    assert_equal "The Total row on the 2023 tab says −$12.00", total_check_sentence(Import::StatedTotal.new(tab: "2023", cents: -1_200), "history.xlsx")
    assert_nil total_check_sentence(nil, "personal.csv")
  end

  test "a list shows 20 rows and counts the rest" do
    assert_equal [ 0, 0, 1, 80 ], [ 0, 20, 21, 100 ].map { |size| rows_not_shown(Array.new(size)) }
  end

  test "the matched categories read as a few examples once there are more than three" do
    assert_equal "4 matched, like groceries, rent and travel", matched_summary(words(%w[ groceries rent travel coffee ]), words(%w[ misc ]))
    assert_equal "groceries and rent matched", matched_summary(words(%w[ groceries rent ]), words(%w[ misc ]))
    assert_equal "Every category matched yours.", matched_summary(words(%w[ groceries rent ]), [])
  end

  test "the lead counts the matched categories and the ones left to choose" do
    assert_equal "4 categories matched yours. Choose what the other 2 become.", categories_lead(words(%w[ a b c d ]), words(%w[ e f ]))
    assert_equal "1 category matched yours. Choose what the other one becomes.", categories_lead(words(%w[ a ]), words(%w[ b ]))
    assert_equal "Choose what each category becomes.", categories_lead([], words(%w[ a b ]))
  end

  test "the money-in line counts the word's money in" do
    assert_equal %(1 is <span class="text-success">money in</span>), money_in_sentence(category_word(money_in_count: 1))
    assert_equal %(16 are <span class="text-success">money in</span>), money_in_sentence(category_word(money_in_count: 16))
    assert_equal %(1,200 are <span class="text-success">money in</span>), money_in_sentence(category_word(money_in_count: 1_200))
  end

  test "a word that isn't one of yours can become a new category" do
    assert_equal [ [ "New category", "work" ], [ "Food", "Food" ], [ "No category", "" ] ], category_choices(category_word, [ "Food" ])
    assert_equal [ [ "Food", "Food" ], [ "No category", "" ] ], category_choices(category_word(word: "food", matched: true), [ "Food" ])
  end

  test "money in goes to an income category, or stays a refund to the word's category" do
    assert_equal [ [ "Income", "Income" ], [ "Side gigs", "Side gigs" ], [ "Refund to work", "" ] ],
      money_in_choices(category_word(name: "work"), [ "Income", "Side gigs" ])
  end

  private
    def words(list)
      list.map { |word| category_word(word:, name: word) }
    end

    def category_word(**attributes)
      Import::CategoryWord.new(word: "work", count: 1, money_in_count: 0, matched: false, name: "work", income: false, money_in_name: nil, **attributes)
    end
end
