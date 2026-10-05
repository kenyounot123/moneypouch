# Transaction::Draft

## Sub-features

- `Transaction::Draft::Grammar.read(line, today:)` reads a typed line into a `Transaction::Draft::Reading` with `name`, `amount_in_cents`, `category_word`, `occurred_on`, `dated`, and `errors`. It is pure. `dated` is true only when the line names a date, so `coffee 5` is not dated and `coffee 5 today` is.
- `Transaction::Draft.parse(line, user:, today:, complete: false, editing: nil)` adds the category and never writes.
  - With `complete: true`, a line of 2 or more non-space characters with no digit, `#`, `@`, `$`, or `+` looks up the user's kept names that start with it (ASCII case-insensitive, LIKE wildcards escaped), ranked by use count then latest `occurred_on`, and takes the first longer than the line. `#completion` is the full completed name in its stored spelling, or nil. The category then comes from the completed name. The lookup is `Transaction.name_starting_with`.
  - A `#word` matches the user's category, ignoring ASCII case. No match gives an unsaved `Category`.
  - With no `#word`, the category comes from the user's latest kept transaction with the same name, skipping the `editing:` row. This runs even when the amount is missing, so the preview shows the category while the person is still typing. A line with no name skips the lookup.
- Amounts: `5`, `5.50`, `$5.50`, `.50`, `-5`, `1,650` read as money out. A leading `+` reads as money in. A marked amount (`$`, a sign, cents, or a thousands comma) wins over bare numbers, else the last bare number wins.
- Dates: `sep 26`, `sep 1st`, `sep 26 2025`, `9/26`, `9/26/26`, `2026-09-26`, `today`, `yesterday`, and full weekday names. No date means `today`.
- Errors: `Type an amount, like 5.50` and `Type a name, like coffee`.
- A bare `#` is taken out of the name and leaves the category to inference: `Trader Joe's 64.12 #` reads name `Trader Joe's`. A `#` followed only by punctuation, like `#!`, stays in the name.
- `#attributes`, `#valid?`, `#money_in?`, `#dated?`, `#completion`, `#category_word`, `#category_name`, `#inferred?`.

## How to get to it (user POV)

A user reaches it through the quick add bar on `/`. Every keystroke renders `GET /draft?line=...`, see [quick-add-bar.md](quick-add-bar.md). The Ruby API is also driven directly through `query`.

## Driving it with mp.mjs

`query` needs no running instance. Pass a fixed `today:` so dates are reproducible.

- Read a line:
  `mp.mjs query 'd = Transaction::Draft.parse("coffee 5.50 yesterday", user: User.find_by!(username: "demo"), today: Date.new(2026, 9, 27)); d.attributes.merge(errors: d.errors, category: d.category_name, inferred: d.inferred?)'`
  prints `name: "coffee", amount_in_cents: -550, occurred_on: Sat, 26 Sep 2026`, `errors: []`.
- Grammar only: `mp.mjs query 'Transaction::Draft::Grammar.read("Forever 21 $40 sep 26 #shopping", today: Date.new(2026, 9, 27)).to_h'` prints `name: "Forever 21", amount_in_cents: -4000, category_word: "shopping"`.
- Inference: run `bin/rails "dev:transactions[100]"` first, then parse a name that exists, such as `"Blue Bottle Mission 4.75"`. `[d.category_name, d.inferred?, d.category.persisted?]` prints `["Food", true, true]`.
- New category: `"lunch 12 #brandnew"` gives `d.category.persisted?` `false`, and `Category.count` is unchanged.
- Errors: `"coffee"` gives `["Type an amount, like 5.50"]`. `"5"` gives `["Type a name, like coffee"]`.
- Completion: `mp.mjs query 'Transaction::Draft.parse("Tra", user: User.find_by!(username: "demo"), today: Date.current, complete: true).then { [_1.completion, _1.category_name] }'` prints `["Trader Joe's", "Groceries"]` when the history holds `Trader Joe's`.
- No writes: `query` opens SQLite read-only, so a parse that wrote would raise `SQLite3::ReadOnlyException`. Also compare `Transaction.count` and `Category.count` before and after.

## Gotchas

- `today:` is required. In a request `Date.current` is the browser's zone from the `time_zone` cookie (UTC when the cookie is missing or unknown). In `query` it is the app zone, UTC, so a lane run near midnight can shift `today` and `yesterday`.
- The `demo` user has no transactions in a fresh database, so inference returns `nil` until `dev:transactions` runs. Its names look like `Blue Bottle` or `Blue Bottle Mission`, not `coffee`.
- A weekday word inside a name reads as a date: `Ruby Tuesday 25` reads `name: "Ruby"`.
- An impossible date such as `feb 30` stays in the name, and a typed year outside 20 years back to 1 year ahead stays in the name.
- An amount of zero or over 7 dollar digits stays in the name.
- Shell quoting: wrap the Ruby in single quotes and use double quotes inside. A `$` inside single quotes is safe.
