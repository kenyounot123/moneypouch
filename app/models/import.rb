class Import < ApplicationRecord
  belongs_to :user
  has_many :transactions
  has_many :created_categories, class_name: "Category"

  serialize :sheet, coder: Import::Sheet
  serialize :columns, coder: Import::Columns
  serialize :category_names, coder: JSON
  serialize :money_in_names, coder: JSON

  delegate :rows, :unreadable_rows, :category_words, :tally, to: :reading

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
    forget_reading
    super
  end

  def category_names=(category_names)
    forget_reading
    super
  end

  def money_in_names=(money_in_names)
    forget_reading
    super
  end

  def reload(*)
    forget_reading
    super
  end

  def draft?
    completed_at.nil?
  end

  def completed?
    completed_at.present?
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
    def reading
      @reading ||= Import::Reading.new(sheet:, columns:, category_names:, money_in_names:, user:)
    end

    def forget_reading
      @reading = nil
    end

    def add_transactions
      categories_by_name = {}

      if user.transactions.import(reading.new_rows, import: self) { |row| category_for(row, categories_by_name) }.zero?
        destroy!
      else
        update!(completed_at: Time.current, sheet: nil)
      end
    end

    def category_for(row, categories_by_name)
      category_word = reading.category_word_for(row)
      name = category_word.category_name_for(row)

      if name.present?
        categories_by_name[name.downcase(:ascii)] ||= user.categories.named(name).first ||
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
