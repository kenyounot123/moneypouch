class Help::Topic < Data.define(:slug, :title, :section, :pages)
  CATALOG = {
    "Adding" => [
      [ "type-a-transaction", "Type a transaction", %w[ overview transactions ] ],
      [ "finish-faster", "Finish a line faster", %w[ overview ] ],
      [ "undo-an-add", "Undo an add", %w[ overview ] ],
      [ "fix-a-transaction", "Fix or delete a transaction", %w[ transactions ] ]
    ],
    "What counts" => [
      [ "spent", "Spent", [] ],
      [ "income", "Income", [] ],
      [ "net", "Net", [] ],
      [ "refund", "Record a refund", %w[ transactions ] ],
      [ "transfer", "Mark a transfer", %w[ transactions ] ],
      [ "excluded", "Leave one out of the totals", %w[ transactions ] ]
    ],
    "Categories" => [
      [ "make-a-category", "Make a category", %w[ categories overview ] ],
      [ "change-a-category", "Change a transaction's category", [] ],
      [ "manage-a-category", "Rename, merge, or delete a category", %w[ categories ] ],
      [ "uncategorized", "Uncategorized", [] ]
    ],
    "Searching" => [
      [ "search-transactions", "Search transactions", %w[ transactions ] ]
    ],
    "Import" => [
      [ "import-a-file", "Import a file", %w[ import ] ],
      [ "import-again", "Import the same file again", %w[ import ] ],
      [ "undo-an-import", "Undo an import", %w[ import ] ]
    ],
    "Bank sync" => [
      [ "connect-a-bank", "Connect a bank", %w[ settings ] ],
      [ "gold-square", "The gold square", [] ],
      [ "make-a-rule", "Use the same category every time", %w[ review ] ],
      [ "possible-duplicates", "Possible duplicates", [] ],
      [ "automatic-transfers", "Why a transfer was marked for me", %w[ review transactions ] ]
    ],
    "Trends" => [
      [ "empty-trends", "Why Trends is empty", %w[ trends ] ]
    ],
    "Your data" => [
      [ "download", "Download everything", %w[ settings ] ],
      [ "shortcuts", "See every shortcut", %w[ settings ] ]
    ]
  }.freeze

  ALL = CATALOG.flat_map { |section, rows| rows.map { |slug, title, pages| new(slug:, title:, section:, pages:) } }.freeze

  class << self
    def sections
      ALL.group_by(&:section)
    end

    def on(page)
      ALL.select { |topic| topic.pages.include?(page) }
    end
  end

  def id
    "help-#{slug}"
  end

  def partial
    "help/topics/#{slug.underscore}"
  end
end
