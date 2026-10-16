# Transactions ledger

## Sub-features

- `/transactions` shows one month, `?month=YYYY-MM`. A missing or unreadable month is this month, and a future month clamps to this month (`Month` in `app/models/month.rb`).
- Header: `Spent in <Month>` over the total in `.text-display`, then `dl dd` Income, Net, and Transactions when the main column is at least `@xl` (576px), or one `Income … · Net … · N transactions` line below that. All three follow the filters. `spent` matches the Overview's month total, `net` is every counted row (not a transfer, not excluded), and income is `net + spent`.
- Month switcher `nav[aria-label=Month]`: `‹ Sep`, the current `October 2026` (`[aria-current]`), and `Nov ›` only for a past month. Phones get a compact copy in the top row next to `‹ Overview`. Month links keep the filters.
- Filters are a GET form: `#query` (name or note, case-insensitive), `select#account` (each bank account, `typed` for rows with no bank row), `select#category` (each category by id, `none` for uncategorized), each select submitting on change. The chip `a[aria-pressed]` toggles `needs=1` and counts the filtered rows that need a category, which are exactly the rows with the gold marker. Below `@xl` the selects hide behind the `Filters` label (`label[for=filters_toggle]`).
- Rows group by day, newest first. From `@xl` each day is a `section` with a 96px date gutter (day total only when the day has more than one row) and `li#transaction_<id>` rows 40px tall with lanes for the marker, the name and note, the category, the account (from `@4xl`, 896px), and the amount. A row that needs a category shows the bordered `Category` field, any other row its dotted category. Both open `category-picker`. Hover or focus shows `Add a note` (when there is no note) and a `Delete` `button_to` that asks for confirmation. Below `@xl` rows are two lines under a full-width day header, with no hover controls.
- Excluded: from `@xl`, hover or focus shows `Exclude` (`Include` on an excluded row) beside `Delete`, a `button_to` to `PATCH /transactions/:id/exclusion` (`transaction[excluded]=true|false`, `Transactions::ExclusionsController`). An excluded row dims its name and amount, shows an `Excluded` tag after the name (hidden while hovered), and drops out of the header totals. Below `@xl` the line reads `Category · Excluded` and the phone sheet has `Exclude` or `Include` next to `Delete`, with `Excluded` in its date line. The day total (`@day_totals`) still sums every row.
- Pages: a busy month renders whole days, newest first, until it holds at least 100 rows (`Transaction::Page`). The rest follows in nested `turbo-frame#days_<YYYY-MM-DD>[loading=lazy][refresh=morph]` frames, `?before=<date>` meaning the days before that date, each loaded as it scrolls into view. Header totals and the count cover the whole month. A refresh keeps loaded frames and reloads them; one whose start date is no longer a page boundary comes back empty, and the new boundary's frame loads in its place.
- Month end (on the last page only): `That's all of <Month>`, `N transactions · $X spent`, and an outline link to the month before with its count (same filters), shown when any earlier transaction exists. Empty month: `Nothing in <Month>.` No match: `No transactions match.`
- Phone sheet: below `@xl` each row's line is covered by `a[data-turbo-frame=sheet]` to `/transactions/:id/edit`, which renders `turbo-frame#sheet` into `dialog[data-controller=sheet]`. `sheet_controller.js` opens it on `turbo:frame-load` and closes it on a backdrop click, Escape, any form submit inside it, and the morph that follows a save. The sheet holds the category picker at `data-category-picker-size-value=large`, `form#sheet_note`, Delete, and `button[form=sheet_note]` Done, which saves the note.

## How to get to it (user POV)

Sign in and click Transactions in the sidebar, or the count link under Recent. On a phone, the page opens from that count link.

## Driving it with mp.mjs

- Desktop rows hide their phone line, so target the visible lane: `$M hover '#transaction_N div.h-10 p.font-mono'`, then `$M click '#transaction_N div.h-10 form button'` for Delete or `'#transaction_N div.h-10 button[data-action="category-picker#open"]'` for the picker.
- Selects: `mp.mjs` has no select command. Set the value and dispatch `change` with `js` to exercise the auto-submit.
- Sheet: `$M resize 390 844`, `$M click '#transaction_N a[data-turbo-frame=sheet]'`, `$M wait 'turbo-frame#sheet h2' --text ''`, then read `document.querySelector("dialog[data-controller=sheet]").open`.
- Seeded `demo` data from bank sync gives a current month of about 45 rows with dozens needing a category.

## Gotchas

- Other screens refresh at commit: `Transaction` broadcasts `refresh` on `[user, :transactions]` from `after_commit`, not through `broadcasts_refreshes_to`'s debounced job, and `application.js` sets Turbo's refresh debounce to 50 ms. Bulk writes (sync, import) wrap in `Transaction.broadcasting_once_for`.
- A month needs more than 100 rows to page. `bin/rails "dev:transactions[12000]"` gives about 1,000 per month.
- Rows added by the bank have no shorthand, so deleting one leaves nothing in the composer to undo with. Restore with `Transaction#restore` from `bin/rails runner`.
- The container breakpoints are on `main`, so a collapsed sidebar can switch the layout at the same window width.
