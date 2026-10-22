class User < ApplicationRecord
  has_secure_password

  THEMES = %w[ light dark ]

  validates :username, presence: true, uniqueness: true
  validates :theme, inclusion: { in: THEMES }

  has_many :sessions, dependent: :destroy

  has_many :transactions, -> { kept }
  has_many :categories, dependent: :destroy
  has_many :bank_accounts, dependent: :destroy
  has_many :bank_transactions, through: :bank_accounts
  has_many :rules, dependent: :destroy
  has_many :imports, dependent: :destroy

  has_one :simplefin_access, class_name: "Simplefin::Access", dependent: :destroy

  attribute :seen_version, default: -> { Release.current_version }

  after_create :create_income_category

  def connect_simplefin(setup_token)
    (simplefin_access || build_simplefin_access).tap do |access|
      access.connect(setup_token)
    end
  end

  def start_import(file)
    import = imports.new(file:)

    if import.valid?
      transaction do
        imports.drafts.destroy_all
        import.save!
      end
    end

    import
  end

  # A name ActiveSupport can't read leaves the saved zone alone.
  def adopt_time_zone(name)
    zone = ActiveSupport::TimeZone[name.to_s]

    if zone
      update!(time_zone: zone.name)
    end
  end

  def choose_theme(theme)
    update!(theme:)
  end

  def unseen_releases
    Release.newer_than(seen_version)
  end

  def see_releases
    update!(seen_version: Release.current_version)
  end

  def income_category
    categories.income.named("Income").first
  end

  def latest_import
    imports.completed.order(:completed_at).last
  end

  def remember(name, categorization)
    remember_once(name, categorization)
  rescue ActiveRecord::RecordNotUnique
    remember_once(name, categorization)
  end

  def remembers?(name, categorization)
    rules.find_by(name_key: name.key)&.categorization == categorization
  end

  def imported_already(rows)
    Transaction.where(user: self).already_here(rows)
  end

  def transactions_named(name_key)
    transactions.behind(bank_transactions.unmatched.where(name_key:))
  end

  # Reads the loaded rules, so one sync that shares this user across its accounts loads them once.
  def categorization_for(name)
    rule = rules.find { |rule| rule.matches?(name) }

    if rule
      rule.categorization
    else
      Transaction::Categorization.new(category: transactions.last_category_for(name.to_s))
    end
  end

  private
    def create_income_category
      categories.create!(name: "Income", income: true)
    end

    def remember_once(name, categorization)
      transaction do
        rule = rules.find_or_initialize_by(name_key: name.key)
        rule.update!(name: name.to_s, categorization:)
        rule.apply_to_uncategorized
      end
    end
end
