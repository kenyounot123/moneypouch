require "test_helper"

class WelcomeHelperTest < ActionView::TestCase
  test "counts one transaction in the singular" do
    assert_equal "1 transaction since Oct 2026", transactions_total(1, Date.new(2026, 10, 4))
  end

  test "groups thousands in the count" do
    assert_equal "9,999 transactions since Feb 2025", transactions_total(9999, Date.new(2025, 2, 1))
  end
end
