class Import < ApplicationRecord
  belongs_to :user
  has_many :transactions
  has_many :created_categories, class_name: "Category"

  serialize :sheet, coder: Import::Sheet
  serialize :columns, coder: Import::Columns
  serialize :category_names, coder: JSON

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
      Import::CategoryWord.new(word:, count: rows.size, match:, name:, income: income_name?(name, rows:))
    end.sort_by { |category_word| [ -category_word.count, category_word.word.downcase ] }
  end

  def choose_columns(choice)
    update(columns: Import::Columns.from(choice, sheet:))
  end

  def choose_categories(choices)
    update!(category_names: category_names.merge(choices.to_h { |choice| [ choice[:word], choice[:name].to_s.squish ] }))
  end

  def tally
    words = category_words.index_by(&:word)
    counted = new_rows.select(&:counted?)
    spent = counted.count { |row| spending?(row, words[row.category_word]) }
    transfers = new_rows.count(&:transfer?)

    Import::Tally.new(
      spent:,
      income: counted.size - spent,
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
      @readings = @new_rows = @category_words = @user_categories = nil
    end

    def new_rows
      @new_rows ||= rows - Transaction.already_here(rows, user:)
    end

    def user_categories
      @user_categories ||= user.categories.to_a
    end

    def income_name?(name, rows:)
      chosen = user_categories.find { |category| category.named?(name) }

      if chosen
        chosen.income?
      else
        rows.all?(&:money_in?)
      end
    end

    def spending?(row, category_word)
      if category_word&.categorized?
        !category_word.income?
      else
        !row.money_in?
      end
    end

    def add_transactions
      categories = category_words.to_h { |category_word| [ category_word.word, category_for(category_word) ] }

      if user.transactions.import(new_rows, import: self, categories:, income_category: user.income_category).zero?
        destroy!
      else
        update!(completed_at: Time.current, sheet: nil)
      end
    end

    def category_for(category_word)
      if category_word.categorized?
        user.categories.named(category_word.name).first || created_categories.create!(user:, name: category_word.name, income: category_word.income?)
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
