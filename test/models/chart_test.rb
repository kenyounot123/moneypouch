require "test_helper"

class ChartTest < ActiveSupport::TestCase
  test "defaults to spending" do
    assert_equal [ "spending", "spending", "spending" ], [ Chart.new(nil).kind, Chart.new("").kind, Chart.new("pie").kind ]
  end

  test "knows the summary" do
    assert Chart.new("summary").summary?
    assert_not Chart.new("summary").spending?
  end

  test "leaves the default out of a URL" do
    assert_nil Chart.new("spending").to_param
    assert_equal "summary", Chart.new("summary").to_param
  end
end
