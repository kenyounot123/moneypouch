require "test_helper"

class MoneyHelperTest < ActionView::TestCase
  test "writes cents as dollars, with a real minus below zero" do
    assert_equal [ "$5.50", "$0.00", "−$5.50" ], [ money(550), money(0), money(-550) ]
  end

  test "rounds money to whole dollars" do
    assert_equal [ "$7,890", "$3,977", "$0", "$1" ], [ money(789_000, whole: true), money(397_712, whole: true), money(0, whole: true), money(50, whole: true) ]
  end

  test "signs a net, with a real minus for a loss" do
    assert_equal [ "+$3,913", "−$310", "$0" ], [ signed_money(391_288, whole: true), signed_money(-31_000, whole: true), signed_money(0, whole: true) ]
    assert_equal [ "+$3,912.88", "−$310.00", "$0.00" ], [ signed_money(391_288), signed_money(-31_000), signed_money(0) ]
  end

  test "writes money out plain and money in with a plus" do
    assert_equal [ "$5.50", "$0.00", "+$2,400.00" ], [ money_flow(-550), money_flow(0), money_flow(240000) ]
  end

  test "colors money in green and leaves the rest to the caller" do
    assert_equal [ "text-success", nil, nil ], [ money_color(240000), money_color(-550), money_color(0) ]
    assert_equal [ "text-success", "text-tertiary", "text-tertiary" ],
      [ money_color(240000, otherwise: "text-tertiary"), money_color(-550, otherwise: "text-tertiary"), money_color(0, otherwise: "text-tertiary") ]
  end
end
