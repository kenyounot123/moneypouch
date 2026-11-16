class Transaction::FlatPage
  attr_reader :number

  def initialize(transactions, count:, number:)
    @transactions = transactions
    @count = count
    @number = number
  end

  def transactions
    @transactions.limit(Transaction::Page::ROWS).offset((number - 1) * Transaction::Page::ROWS)
  end

  def next_number
    if number * Transaction::Page::ROWS < @count
      number + 1
    end
  end

  def frame_id
    [ "rows", (number if number > 1) ].compact.join("_")
  end

  def next_frame_id
    "rows_#{next_number}"
  end

  def next_params
    if next_number
      { page: next_number }
    end
  end
end
