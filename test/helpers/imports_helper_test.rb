require "test_helper"

class ImportsHelperTest < ActionView::TestCase
  test "a row that can't be read names its tab when the file has tabs" do
    assert_equal "2023, row 214", unreadable_place(Import::UnreadableRow.new(tab: "2023", number: 214, reason: "there's no amount"))
    assert_equal "Row 12", unreadable_place(Import::UnreadableRow.new(tab: nil, number: 12, reason: "there's no amount"))
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
