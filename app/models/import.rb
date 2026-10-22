class Import < ApplicationRecord
  belongs_to :user
  has_many :transactions
  has_many :created_categories, class_name: "Category"

  serialize :sheet, coder: Import::Sheet
  serialize :columns, coder: Import::Columns
  serialize :category_names, coder: JSON
  serialize :money_in_names, coder: JSON

  scope :drafts, -> { where(completed_at: nil) }
  scope :completed, -> { where.not(completed_at: nil) }

  validate :file_readable, on: :create
  validate :columns_complete, on: :update, if: :draft?

  def file=(file)
    if file.present?
      self.filename = file.original_filename
      self.sheet = Import::Sheet.read(file)
      self.columns = Import::Columns.guess(sheet)
    end
  rescue Import::Sheet::Unreadable => error
    @unreadable_file = error.message
  end

  def columns=(columns)
    forget_readings
    super
  end

  def category_names=(category_names)
    forget_readings
    super
  end

  def money_in_names=(money_in_names)
    forget_readings
    super
  end

  def reload(*)
    forget_readings
    super
  end

  def draft?
    completed_at.nil?
  end

  def completed?
    completed_at.present?
  end

  def rows
    readings.grep(Import::Row)
  end

  def unreadable_rows
    readings.grep(Import::UnreadableRow)
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

  def choose_columns(choice)
    update(columns: Import::Columns.from(choice, sheet:))
  end

  # A choice without :money_in (the word showed no second line) leaves that word's money-in choice as it was.
  def choose_categories(choices)
    names = choices.to_h { |choice| [ choice[:word], choice[:name].to_s.squish ] }
    money_in = choices.reject { |choice| choice[:money_in].nil? }.to_h { |choice| [ choice[:word], choice[:money_in].to_s.squish ] }

    update!(category_names: category_names.merge(names), money_in_names: money_in_names.merge(money_in))
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

  def latest_occurred_on
    transactions.maximum(:occurred_on)
  end

  def complete
    Transaction.broadcasting_once_for(user) do
      with_lock do
        if draft? && valid?
          add_transactions
        end
      end
    end
  end

  def undo
    Transaction.broadcasting_once_for(user) do
      transaction do
        transactions.matchable.delete_all
        created_categories.unused.destroy_all
        destroy!
      end
    end
  end

  private
    def readings
      @readings ||= columns.read(sheet)
    end

    def forget_readings
      @readings = @new_rows = @rows_by_word = @category_words = @category_words_by_word = @user_categories = @income_category = @categories_by_name = nil
    end

    def new_rows
      @new_rows ||= rows - Transaction.already_here(rows, user:)
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

    def category_word_for(row)
      @category_words_by_word ||= category_words.index_by(&:word)
      @category_words_by_word.fetch(row.category_word) { Import::CategoryWord.uncategorized(money_in_name: income_category&.name) }
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

    def add_transactions
      if user.transactions.import(new_rows, import: self) { |row| category_for(row) }.zero?
        destroy!
      else
        update!(completed_at: Time.current, sheet: nil)
      end
    end

    def category_for(row)
      category_word = category_word_for(row)
      name = category_word.category_name_for(row)

      if name.present?
        @categories_by_name ||= {}
        @categories_by_name[name.downcase(:ascii)] ||= user.categories.named(name).first ||
          created_categories.create!(user:, name:, income: category_word.income?)
      end
    end

    def file_readable
      if @unreadable_file
        errors.add(:file, @unreadable_file)
      elsif sheet.nil?
        errors.add(:file, "Choose a file.")
      end
    end

    def columns_complete
      columns.errors.each do |message|
        errors.add(:columns, message)
      end
    end
end
