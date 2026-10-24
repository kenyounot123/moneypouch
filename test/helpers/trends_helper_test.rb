require "test_helper"

class TrendsHelperTest < ActionView::TestCase
  test "shades a month by its share of the category's busiest month, in four steps over an empty track" do
    assert_equal %w[ bg-data-track bg-data/40 bg-data/40 bg-data/60 bg-data/80 bg-data ],
      [ 0, 1, 2_500, 5_000, 7_500, 10_000 ].map { |cents| heat_class cents, 10_000 }
  end
end
