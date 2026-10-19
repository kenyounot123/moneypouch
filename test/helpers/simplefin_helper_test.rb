require "test_helper"

class SimplefinHelperTest < ActionView::TestCase
  test "says how many rows need a category" do
    assert_equal "1 needs a category", need_a_category(1)
    assert_equal "9 need a category", need_a_category(9)
  end
end
