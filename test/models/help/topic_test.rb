require "test_helper"

class Help::TopicTest < ActiveSupport::TestCase
  test "groups the topics by section in reading order" do
    assert_equal [ "Adding", "What counts", "Categories", "Searching", "Import", "Bank sync", "Trends", "Your data" ], Help::Topic.sections.keys
    assert_equal [ "Type a transaction", "Finish a line faster", "Undo an add", "Fix or delete a transaction" ], Help::Topic.sections["Adding"].map(&:title)
  end

  test "gives each topic its own anchor" do
    ids = Help::Topic::ALL.map(&:id)

    assert_equal ids.uniq, ids
    assert_equal "help-type-a-transaction", Help::Topic.sections["Adding"].first.id
  end

  test "lists the topics that belong on a page" do
    assert_equal [ "Type a transaction", "Finish a line faster", "Undo an add", "Make a category" ], Help::Topic.on("overview").map(&:title)
    assert_includes Help::Topic.on("transactions").map(&:slug), "refund"
    assert_empty Help::Topic.on("nowhere")
  end

  test "every page that has help names topics for it" do
    HelpHelper::PAGES.values.uniq.each do |page|
      assert_not_empty Help::Topic.on(page), "#{page} has no topics"
    end
  end
end
