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

  def new_rows
    @new_rows ||= rows - user.imported_already(rows)
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
    counted = new_rows.select(&:counted?)
    counts = counted.map { |row| category_word_for(row).counts_as(row) }.tally
    transfers = new_rows.count(&:transfer?)

    Import::Tally.new(
      spent: counts.fetch(:spent, 0),
      refunds: counts.fetch(:refund, 0),
      income: counts.fetch(:income, 0),
      transfers:,
      excluded: new_rows.size - counted.size - transfers,
      unreadable: unreadable_rows.size,
      already_here: rows.size - new_rows.size
    )
  end

  private
    attr_reader :sheet, :columns, :category_names, :money_in_names, :user

    def readings
      @readings ||= columns.read(sheet)
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
