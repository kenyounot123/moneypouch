class Transaction::Duplicates
  include Enumerable

  DAYS_FROM_ONE = 7
  DAYS_FROM_SEVERAL = 3
  DAYS_BETWEEN_SEVERAL = 1
  SMALLEST_RUN = 3
  BATCH = 50

  def initialize(user)
    @user = user
    @claimed = Set.new
  end

  def each(&)
    matches.each_slice(BATCH) { |batch| duplicates_from(batch).each(&) }
  end

  def size
    matches.size
  end

  def empty?
    matches.empty?
  end

  def between(transaction_id, bank_transaction_ids)
    duplicates_from(matches.select { |match| match.between?(transaction_id, bank_transaction_ids) }).first
  end

  private
    def duplicates_from(matches)
      transactions = @user.transactions.where(id: matches.flat_map(&:ids)).includes(:import, bank_transaction: :bank_account).index_by(&:id)

      matches.map do |match|
        typed, *bank_rows = transactions.fetch_values(*match.ids)
        Transaction::Duplicate.new(typed:, bank_rows:)
      end
    end

    def matches
      @matches ||= claim { |typed| one_row(typed) } + claim { |typed| two_rows(typed) } + claim { |typed| run_of_rows(typed) }
    end

    def claim(&)
      typed_rows.reject { |typed| @claimed.include?(typed.id) }.flat_map(&).sort_by(&:rank).select do |match|
        if @claimed.disjoint?(match.ids)
          @claimed.merge(match.ids)
        end
      end
    end

    def one_row(typed)
      bank_rows_by_money.fetch(typed.money, []).filter_map { |bank_row| match(typed, [ bank_row ], within: DAYS_FROM_ONE) }
    end

    def two_rows(typed)
      pairs_by_money.fetch(typed.money, []).filter_map { |pair| match(typed, pair, within: DAYS_FROM_SEVERAL) }
    end

    def run_of_rows(typed)
      repeated_bank_rows.flat_map do |alike|
        length = alike.first.times_into(typed)

        if length >= SMALLEST_RUN
          runs(alike.select { |bank_row| free?(bank_row, typed) }, length).filter_map { |run| match(typed, run, within: DAYS_FROM_SEVERAL) }
        else
          []
        end
      end
    end

    def runs(alike, length)
      alike.each_cons(length).select { |run| run.first.days_from(run.last) <= DAYS_BETWEEN_SEVERAL }
    end

    def match(typed, bank_rows, within:)
      if bank_rows.all? { |bank_row| bank_row.days_from(typed) <= within && free?(bank_row, typed) }
        Match.new(typed:, bank_rows:)
      end
    end

    def free?(bank_row, typed)
      !@claimed.include?(bank_row.id) && !kept_apart.include?([ typed.id, bank_row.bank_transaction_id ])
    end

    def bank_rows
      @bank_rows ||= @user.transactions.possibly_repeated.order(:occurred_on, :id)
        .pluck(:id, :currency, :amount_in_cents, :occurred_on, "bank_transactions.id", "bank_transactions.name_key")
        .map { |id, currency, amount_in_cents, occurred_on, bank_transaction_id, name_key| Row.new(id:, currency:, amount_in_cents:, occurred_on:, bank_transaction_id:, name_key:) }
    end

    def bank_rows_by_money
      @bank_rows_by_money ||= bank_rows.group_by(&:money)
    end

    def pairs_by_money
      @pairs_by_money ||= pairs_of_bank_rows.group_by { |first, second| first.money_with(second) }
    end

    def pairs_of_bank_rows
      bank_rows_by_date = bank_rows.group_by(&:occurred_on)

      bank_rows.flat_map do |first|
        (first.occurred_on..(first.occurred_on + DAYS_BETWEEN_SEVERAL)).flat_map { |date| bank_rows_by_date.fetch(date, []) }
          .select { |second| first.before?(second) && first.same_direction?(second) }
          .map { |second| [ first, second ] }
      end
    end

    def repeated_bank_rows
      @repeated_bank_rows ||= bank_rows.group_by { |bank_row| [ bank_row.name_key, bank_row.money ] }.values.select { |alike| alike.size >= SMALLEST_RUN }
    end

    def typed_rows
      @typed_rows ||= @user.transactions.possibly_repeating.occurred_in(dates_near_bank_rows)
        .pluck(:id, :currency, :amount_in_cents, :occurred_on)
        .map { |id, currency, amount_in_cents, occurred_on| Row.new(id:, currency:, amount_in_cents:, occurred_on:) }
    end

    def dates_near_bank_rows
      if bank_rows.any?
        (bank_rows.first.occurred_on - DAYS_FROM_ONE)..(bank_rows.last.occurred_on + DAYS_FROM_ONE)
      else
        []
      end
    end

    def kept_apart
      @kept_apart ||= Transaction::DuplicateAnswer.different.where(typed_transaction: @user.transactions).pluck(:typed_transaction_id, :bank_transaction_id).to_set
    end
end
