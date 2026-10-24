require "test_helper"

class Trends::NoteTest < ActiveSupport::TestCase
  test "is good or neutral news" do
    assert_equal :good, Trends::Note.new(kind: :kept_months, tone: :good, text: "Fine.").tone
    assert_equal [ :neutral, nil ], Trends::Note.new(kind: :x, tone: :neutral, text: "Fine.").then { |note| [ note.tone, note.path ] }
  end

  test "refuses any other tone" do
    [ :bad, :warning, "good", nil ].each do |tone|
      assert_raises(ArgumentError) { Trends::Note.new(kind: :x, tone:, text: "Hmm.") }
    end
  end
end
