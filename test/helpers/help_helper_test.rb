require "test_helper"

class HelpHelperTest < ActionView::TestCase
  test "every page that has help has a glossary" do
    HelpHelper::PAGES.values.uniq.each do |page|
      assert_predicate render(partial: "help/pages/#{page}").strip, :present?, "#{page} has no glossary"
    end
  end
end
