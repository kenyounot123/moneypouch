module User::SampleTransactions
  EVERYDAY = {
    "Food" => [ [ "Blue Bottle", 4..7 ], [ "Sweetgreen", 12..18 ], [ "Chipotle", 10..16 ], [ "Joe's Pizza", 4..12 ],
                [ "Starbucks", 3..8 ], [ "Shake Shack", 11..20 ], [ "Pho Saigon", 13..19 ], [ "Taco Bell", 6..12 ] ],
    "Groceries" => [ [ "Trader Joe's", 25..90 ], [ "Whole Foods", 30..140 ], [ "Safeway", 20..110 ], [ "Costco", 80..260 ] ],
    "Transport" => [ [ "Uber", 9..38 ], [ "Lyft", 8..34 ], [ "Shell", 35..70 ], [ "Clipper", 2..10 ] ],
    "Shopping" => [ [ "Amazon", 8..120 ], [ "Target", 15..95 ], [ "Uniqlo", 25..80 ], [ "Ikea", 20..240 ] ],
    "Fun" => [ [ "AMC", 14..40 ], [ "Steam", 5..60 ] ],
    "Health" => [ [ "CVS", 6..45 ], [ "Walgreens", 5..40 ] ]
  }.flat_map { |category, list| list.map { |name, dollars| [ name, dollars, category ] } }.freeze

  PLACES = %w[ Mission SoMa Marina Castro Richmond Sunset Noe Haight Dogpatch Presidio Bernal Embarcadero Nob Hill
               Potrero Excelsior Bayview Tenderloin Chinatown Fillmore Hayes Downtown Midtown Uptown Oakland Berkeley
               Emeryville Alameda Fremont Hayward Sausalito Burlingame Menlo Cupertino Sunnyvale Campbell Saratoga
               Tiburon Napa Sonoma Petaluma Novato Larkspur Pacifica Millbrae Belmont Woodside Atherton Milpitas
               Livermore Pleasanton Dublin Danville Lafayette Orinda Walnut Concord Martinez Benicia Vallejo
               Albany Piedmont Montclair Rockridge Temescal Fruitvale Jingletown ].freeze

  # Every fourth purchase names a branch ("Uber Mission"), so search and Tab completion have many names to match.
  BRANCHES = EVERYDAY.product(PLACES).map { |(name, dollars, category), place| [ "#{name} #{place}", dollars, category ] }.freeze

  # The same day every month, so Trends finds them as recurring charges and income.
  MONTHLY = [
    [ "Paycheck", 1, 2650..2650, Category::INCOME ], [ "Paycheck", 15, 2650..2650, Category::INCOME ],
    [ "Rent", 1, -2100..-2100, "Bills" ], [ "Equinox", 3, -240..-240, "Health" ], [ "Netflix", 7, -15..-15, "Fun" ],
    [ "Comcast", 12, -80..-80, "Bills" ], [ "Verizon", 18, -65..-65, "Bills" ], [ "Spotify", 22, -11..-11, "Fun" ],
    [ "PG&E", 26, -180..-60, "Bills" ]
  ].freeze

  # Spreads count everyday purchases across the last 12 months, around a year of monthly bills and paychecks.
  def add_sample_transactions(count)
    categories = sample_categories
    today = Date.current

    purchases = Array.new(count) do |index|
      name, dollars, category = (index % 4 == 0) ? BRANCHES[(index / 4) % BRANCHES.size] : EVERYDAY.sample
      sample_row(name, -rand((dollars.begin * 100)..(dollars.end * 100)), today - rand(365), categories.fetch(category))
    end

    monthly = (today - 364).upto(today).flat_map do |day|
      MONTHLY.select { |_, monthday| monthday == day.day }.map do |name, _, dollars, category|
        sample_row(name, rand((dollars.begin * 100)..(dollars.end * 100)), day, categories.fetch(category))
      end
    end

    (purchases + monthly).each_slice(1000) { |batch| Transaction.insert_all!(batch) }
  end

  private
    def sample_categories
      (EVERYDAY.map(&:last) + MONTHLY.map(&:last)).uniq.index_with do |name|
        categories.named(name).first_or_create!(name:)
      end
    end

    def sample_row(name, cents, occurred_on, category)
      added_at = occurred_on.in_time_zone.change(hour: rand(7..22), min: rand(60))
      amount = format("%s%.2f", cents.positive? ? "+" : "", cents.abs / 100.0)

      { user_id: id, category_id: category.id, name:, amount_in_cents: cents, currency: "USD", occurred_on:,
        shorthand: "#{name} #{amount} ##{category.name} #{occurred_on.iso8601}", created_at: added_at, updated_at: added_at }
    end
end
