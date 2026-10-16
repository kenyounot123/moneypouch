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
      match = user.categories.named(word).first
      Import::CategoryWord.new(word:, count: rows.size, match:, name: category_names.fetch(word) { default_name(word, match:, rows:) })
    end.sort_by { |category_word| [ -category_word.count, category_word.word.downcase ] }
  end

  def choose_categories(choices)
    update!(category_names: category_names.merge(choices.to_h { |choice| [ choice[:word], choice[:name].to_s.squish ] }))
  end

  def tally
    names = category_words.to_h { |category_word| [ category_word.word, category_word.name ] }
    counted = new_rows.reject(&:excluded?)
    spent = counted.count { |row| Transaction.spending?(row.amount_in_cents, categorized: names[row.category_word].present?) }

    Import::Tally.new(
      spent:,
      income: counted.size - spent,
      excluded: new_rows.size - counted.size,
      unreadable: unreadable_rows.size,
      already_here: rows.size - new_rows.size
    )
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
      @readings = @new_rows = @category_words = nil
    end

    def new_rows
      @new_rows ||= begin
        taken = Transaction.taken_keys(rows.map(&:key), user:)
        rows.reject { |row| taken.include?(row.key) }
      end
    end

    def default_name(word, match:, rows:)
      if match
        match.name
      elsif rows.all? { |row| row.amount_in_cents.positive? }
        ""
      else
        word
      end
    end

    def add_transactions
      categories = category_words.to_h { |category_word| [ category_word.word, category_named(category_word.name) ] }

      if user.transactions.import(rows, import: self, categories:).zero?
        destroy!
      else
        update!(completed_at: Time.current, sheet: nil)
      end
    end

    def category_named(name)
      if name.present?
        user.categories.named(name).first || created_categories.create!(user:, name:)
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
