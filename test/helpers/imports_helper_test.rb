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

  private
    def words(list)
      list.map { |word| Import::CategoryWord.new(word:, count: 1, money_in_count: 0, match: nil, name: word, income: false, money_in_name: nil) }
    end
end
