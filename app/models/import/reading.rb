# What one sheet says under one choice of columns and category names, worked out once.
# Import keeps one Reading and starts a new one whenever any of these inputs changes.
class Import::Reading
  def initialize(sheet:, columns:, category_names:, money_in_names:, user:)
    @sheet, @columns, @category_names, @money_in_names, @user = sheet, columns, category_names, money_in_names, user
  end

  def rows
    readings.grep(Import::Row)
  end

  def unreadable_rows
    readings.grep(Import::UnreadableRow)
  end

  def stated_totals
    readings.grep(Import::StatedTotal).group_by(&:tab).values.map(&:last)
  end

  def already_here
    @already_here ||= user.imported_already(rows)
  end

  def new_rows
    @new_rows ||= rows.reject { |row| already_here.key?(row) }
  end

  def category_words
    @category_words ||= new_rows.select(&:category_word).group_by(&:category_word).map do |word, rows|
      match = user_categories.find { |category| category.named?(word) }
      name = category_names.fetch(word) { match&.name || word }
      income = income_name?(name, rows:)

      Import::CategoryWord.new(
        word:,
        count: rows.size,
        money_in_count: rows.count(&:money_in?),
        matched: match.present?,
        name:,
        income:,
        money_in_name: money_in_name_for(word, name:, income:)
      )
    end.sort_by { |category_word| [ -category_word.count, category_word.word.downcase ] }
  end

  def category_word_for(row)
    @category_words_by_word ||= category_words.index_by(&:word)
    @category_words_by_word.fetch(row.category_word) { Import::CategoryWord.uncategorized(money_in_name: income_category&.name) }
  end

  def tally
    new_by_kind = new_rows.group_by { |row| kind_of(row) }

    lines = Import::Tally::KINDS.filter_map do |kind|
      if new_by_kind.key?(kind)
        Import::Tally::Line.new(kind:, count: new_by_kind[kind].size, cents: new_by_kind[kind].sum(&:written_cents))
      end
    end

    Import::Tally.new(lines:, already_here:, unreadable_rows:, stated_totals:, rows:)
  end

  private
    attr_reader :sheet, :columns, :category_names, :money_in_names, :user

    def readings
      @readings ||= columns.read(sheet)
    end

    def kind_of(row)
      if row.transfer?
        :transfer
      elsif row.excluded?
        :excluded
      else
        category_word_for(row).counts_as(row)
      end
    end

    def user_categories
      @user_categories ||= user.categories.to_a
    end

    def rows_by_word
      @rows_by_word ||= rows.group_by(&:category_word)
    end

    def income_category
      @income_category ||= user.income_category
    end

    # A stored name that isn't one of the user's income categories, "" included, keeps money in with the word,
    # so a stale or tampered name can never file money in under a spending category.
    def money_in_name_for(word, name:, income:)
      if name.blank?
        income_category&.name
      elsif income
        nil
      else
        chosen = money_in_names.fetch(word) { default_money_in_name(word) }.to_s
        user_categories.find { |category| category.income? && category.named?(chosen) }&.name
      end
    end

    # A refund never comes to more than the spending it lowers.
    def default_money_in_name(word)
      money_in, money_out = rows_by_word.fetch(word).select(&:counted?).partition(&:money_in?)

      if money_in.sum(&:amount_in_cents) > -money_out.sum(&:amount_in_cents)
        income_category&.name
      end
    end

    def income_name?(name, rows:)
      chosen = user_categories.find { |category| category.named?(name) }

      if chosen
        chosen.income?
      else
        rows.all?(&:money_in?)
      end
    end
end
