class User < ApplicationRecord
  has_secure_password

  validates :username, presence: true, uniqueness: true

  has_many :sessions, dependent: :destroy

  has_many :transactions, -> { kept }
  has_many :discarded_transactions, -> { discarded }, class_name: "Transaction"
  has_many :categories, dependent: :destroy
  has_many :bank_accounts, dependent: :destroy
  has_many :bank_transactions, through: :bank_accounts
  has_many :rules, dependent: :destroy

  has_one :simplefin_access, class_name: "Simplefin::Access", dependent: :destroy

  def connect_simplefin(setup_token)
    (simplefin_access || build_simplefin_access).tap do |access|
      access.connect(setup_token)
    end
  end

  def remember(name, categorization)
    remember_once(name, categorization)
  rescue ActiveRecord::RecordNotUnique
    remember_once(name, categorization)
  end

  def remembers?(name, categorization)
    rules.find_by(name_key: name.key)&.categorization == categorization
  end

  def transactions_named(name_key)
    transactions.where(id: bank_transactions.imported.where(name_key:).select(:transaction_id))
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
    def remember_once(name, categorization)
      transaction do
        rule = rules.find_or_initialize_by(name_key: name.key)
        rule.update!(name: name.to_s, category: categorization.category, transfer: categorization.transfer?)
        rule.apply_to_uncategorized
      end
    end
end
