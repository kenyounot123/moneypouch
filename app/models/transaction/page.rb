class Transaction::Page
  ROWS = 50

  attr_reader :before

  def initialize(transactions, counts:, before:)
    @transactions = transactions
    @counts = counts
    @before = before
  end

  def transactions
    if days.any?
      @transactions.occurred_in(Range.new(*days.minmax))
    else
      @transactions.none
    end
  end

  def next_before
    if index && index < runs.size - 1
      days.last
    end
  end

  def frame_id
    [ "days", before ].compact.join("_")
  end

  def next_frame_id
    "days_#{next_before}"
  end

  def next_params
    if next_before
      { before: next_before }
    end
  end

  private
    def days
      if index
        runs[index]
      else
        []
      end
    end

    def index
      if before
        runs.each_cons(2).find_index { |previous, _| previous.last == before }&.next
      elsif runs.any?
        0
      end
    end

    def runs
      @runs ||= begin
        rows = 0

        @counts.keys.slice_before do |date|
          starts_a_page = rows >= ROWS
          rows = 0 if starts_a_page
          rows += @counts[date]
          starts_a_page
        end.to_a
      end
    end
end
