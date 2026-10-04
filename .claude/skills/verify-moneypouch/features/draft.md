# Draft

## Sub-features

- `Draft::Grammar.read(line, today:)` reads a typed line into a `Draft::Reading` with `name`, `amount_in_cents`, `category_word`, `occurred_on`, and `errors`. It is pure.
- `Draft.parse(line, user:, today:, excluding: nil)` adds the category and never writes.
  - A `#word` matches the user's category, ignoring ASCII case. No match gives an unsaved `Category`.
  - With no `#word`, the category comes from the user's latest kept transaction with the same name, skipping the `excluding:` row.
- Amounts: `5`, `5.50`, `$5.50`, `.50`, `-5`, `1,650` read as money out. A leading `+` reads as money in. A marked amount (`$`, a sign, cents, or a thousands comma) wins over bare numbers, else the last bare number wins.
- Dates: `sep 26`, `sep 1st`, `sep 26 2025`, `9/26`, `9/26/26`, `2026-09-26`, `today`, `yesterday`, and full weekday names. No date means `today`.
- Errors: `Add an amount` and `Add a name`.
- `#attributes`, `#valid?`, `#money_in?`, `#category_name`, `#inferred?`.

## How to get to it (user POV)

No page calls `Draft` yet. A user will reach it through the quick add bar on `/`, see [add-transaction.md](add-transaction.md). Until then the surface is the Ruby API, driven through `query`.

## Driving it with mp.mjs

`query` needs no running instance. Pass a fixed `today:` so dates are reproducible.

- Read a line:
  `mp.mjs query 'd = Draft.parse("coffee 5.50 yesterday", user: User.find_by!(username: "demo"), today: Date.new(2026, 9, 27)); d.attributes.merge(errors: d.errors, category: d.category_name, inferred: d.inferred?)'`
  prints `name: "coffee", amount_in_cents: -550, occurred_on: Sat, 26 Sep 2026`, `errors: []`.
- Grammar only: `mp.mjs query 'Draft::Grammar.read("Forever 21 $40 sep 26 #shopping", today: Date.new(2026, 9, 27)).to_h'` prints `name: "Forever 21", amount_in_cents: -4000, category_word: "shopping"`.
- Inference: run `bin/rails "dev:transactions[100]"` first, then parse a name that exists, such as `"Blue Bottle Mission 4.75"`. `[d.category_name, d.inferred?, d.category.persisted?]` prints `["Food", true, true]`.
- New category: `"lunch 12 #brandnew"` gives `d.category.persisted?` `false`, and `Category.count` is unchanged.
- Errors: `"coffee"` gives `["Add an amount"]`. `"5"` gives `["Add a name"]`.
- No writes: `query` opens SQLite read-only, so a parse that wrote would raise `SQLite3::ReadOnlyException`. Also compare `Transaction.count` and `Category.count` before and after.

## Gotchas

- `today:` is required. `Date.current` uses the app time zone, so a lane run near midnight can shift `today` and `yesterday`.
- The `demo` user has no transactions in a fresh database, so inference returns `nil` until `dev:transactions` runs. Its names look like `Blue Bottle` or `Blue Bottle Mission`, not `coffee`.
- A weekday word inside a name reads as a date: `Ruby Tuesday 25` reads `name: "Ruby"`.
- An impossible date such as `feb 30` stays in the name, and a typed year outside 20 years back to 1 year ahead stays in the name.
- An amount of zero or over 7 dollar digits stays in the name.
- Shell quoting: wrap the Ruby in single quotes and use double quotes inside. A `$` inside single quotes is safe.
