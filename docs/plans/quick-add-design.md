# Quick add design

The code shape for [quick-add.md](quick-add.md), P3 to P9. The sketch in [quick-add-sketch/](quick-add-sketch/) mirrors app paths: signatures, `NotImplementedError` bodies, and pseudocode. Owners implement against it. A deviation from the sketch is a finding to raise, not to absorb.

## Problem

One typed line has to mean the same thing in four places: the preview, the save, an edit, and the undo of an edit. Three things make that hard:

- **Relative words drift.** `coffee 5 yesterday`, re-read a week later by an edit or by an undo that PATCHes the previous line, lands on a different day. The plan as written has this bug.
- **Every write changes many figures at once.** One stash or delete moves the Overview total, the category and daily bars, Recent, the month list's day groups and totals, and the sidebar count. That holds on two pages.
- **The budgets are tight.** Preview gets 100 ms per keypress, Enter to painted row gets 300 ms, the Overview gets at most 6 queries at 10k rows, and the 1500-row month list gets 200 ms.

## Usage (caller's view)

```ruby
# preview and save are the same read, against the same anchor day
Current.user.transactions.new.draft("coffee 5.50 yesterday")   # => Draft (pills), never writes
Current.user.transactions.new.stash("coffee 5.50 yesterday")   # => true, saved
transaction.stash("coffee 6 yesterday")                        # edit, and undo of an edit
transaction.discard / transaction.restore

Draft.parse(line, user:, today:)          # the one parser (P4); Draft::Grammar.read is its pure core
Current.user.transactions                 # kept only, by construction
Current.user.discarded_transactions       # only restorations reach this

Spending.new(Current.user.transactions, month: Month.current)   # one grouped query
Month.parse(params[:month])                                      # garbage -> current month
```

```erb
<%= render "shared/quick_add" %>                                       <%# Overview and /transactions %>
<%= render partial: "transactions/transaction", collection: @recent %> <%# one row partial, never streamed %>
<%= render @draft %>                                                   <%# pills or first error, in <turbo-frame id="draft"> %>
```

```js
import { write } from "controllers/support/write"
await write("POST", "/transactions", { line, idempotency_key })   // every mutation, bar or keyboard
```

## Shape

**The parser has one entry point, a pure core, and at most one read.** `Draft.parse(line, user:, today:, excluding:)` keeps the spec's signature. Inside `draft.rb`, `Draft::Grammar.read(line, today:)` is pure and returns a `Reading`. Every grammar test is a literal line with a fixed `today`, and no fixtures are needed. `Draft` then resolves the category with at most one indexed query. A category used for the first time comes back unsaved, and `belongs_to` autosaves it in the same transaction as the row. That way preview never writes, and a new category and its row persist together. Grammar order is month-day, numeric date, relative word, `#word`, amount, then name, so `dec 30 gift 40` reads 30 as a day. This follows boundary-discipline.

**Each saved row anchors its own line.** `ApplicationController` wraps every request in `Time.use_zone(time_zone cookie || UTC)`, so `Date.current` is the user's today everywhere and no `Current.today` is threaded through. `Transaction#draft` and `#stash` read the line against `stashed_on`:

- A new row reads against today.
- A saved row reads against the day it was created, in the user's zone.

So re-reading a row's own `line` reproduces the row, and edit and undo-of-edit cannot drift. The edit-mode preview sends `transaction_id`, so the pills use the same anchor and the same inference exclusion as the PATCH.

**There is one write verb.** `Transaction#stash(line)` serves create, update, and undo-of-edit. Rows are discarded, never destroyed.

**Kept by construction.** `has_many :transactions, -> { kept }` means no read can see a discarded row. Only `Transactions::RestorationsController` reaches `discarded_transactions`. Appendix C's leak risk becomes structural instead of something a grep has to catch, per encode-lessons-in-structure. A replayed DELETE, a PATCH on a discarded row, or a second restore each return 404 and never write twice.

**Create is idempotent at the database.** The bar mints one `idempotency_key` per typed line and keeps it through retries. A unique partial index on `(user_id, idempotency_key)` means triple Enter, a lost response, and a resubmit after the server comes back all converge to one row. A client-side busy flag alone cannot promise that. This follows make-operations-idempotent.

**The server declares undo.** Every write renders `transactions/change.turbo_stream.erb`. That stream appends the inverse request as a `<template>` to the permanent `#undo_entries` and sets the toast:

| Write | Inverse |
|---|---|
| create | DELETE the new row |
| update | PATCH with the previous line |
| destroy | POST a restoration |
| restoration | none |

The client replays the newest entry verbatim with `undo=1`, and a replay's response declares no inverse. So `u` pops and never redoes, and the client never knows route shapes or previous state. The stack is DOM, capped at 50, and ends on reload.

**After a write the page refreshes; rows are not streamed.** After any successful write, `support/write.js` calls `Turbo.visit(location.href, { action: "replace" })`. That is a Turbo 8 page refresh, morphed with scroll preserved. One server render places totals, bars, the day group, the Recent cap, the sidebar count, and a restored row back in its old position. The bar, `#undo_entries`, and `#toast` are `data-turbo-permanent`. This replaces the spec's "prepend to Recent", which cannot move the totals that P6 lane 3 checks. The `refresh` stream action is deliberately not used: turbo-rails 2.0.23 debounces it by 150 ms (`pageRefreshDebouncePeriod`, verified in the gem).

**The preview is a read-back sentence in a turbo-frame.** The prototype compared pills, a read-back sentence, and a draft row. The sentence won: it exposes misreads like `7 eleven` before the save and still shows at phone width. Completion stays a popup under the bar. In-field token highlighting is deferred. quick-add sets `<turbo-frame id="draft">.src` on each input. Turbo's FrameController cancels the in-flight request (verified in the gem), so "keep only the latest response" needs no client code.

**Aggregation lives in a `Month` value and `Spending`.** `Month` is a Data value that owns month boundaries, `?month=` parsing, and elapsed days. It lands in P5 so P6 and P7, which build in parallel, share it. `Spending` runs one `GROUP BY occurred_on, category` over the previous and current month, money out only, and folds every Overview figure from that in Ruby. `Spending::Share`, `Spending::Day`, and `Spending::Comparison` hand each bar to the view. The Overview costs 5 queries: session, user, Spending, Recent, and the sidebar count, which is one `pick` with no class of its own. The month list loads its rows once and sums day totals from them.

**The client is three controllers, each the only owner of its state.**

- `quick-add` owns the line: the preview frame src, the busy flag, the idempotency key, and edit mode.
- `completion` owns the popup. Its ranking is the pure `support/completions.js`. It reaches the bar only by firing a native `input` event.
- `keyboard` on `<body>` owns selection, the dd timer, the undo replay, the toast, and the `?` dialog. It drives the bar through a Stimulus outlet.

`support/write.js` is the only module that sends a write.

**Names.** These were settled by domain-naming over the three candidates:

| Concept | Name | Why |
|---|---|---|
| A line read for one user | `Draft` | "Stash" means a hoard, which fails the precision test. "Line" blurs the text with its reading. A draft is unsaved, editable, and becomes the real thing, and all three hold. "Stash it" stays the UI verb. |
| The typed text | `line` | The spec's own phrase is "one typed line". It is carried as one word through the column, param, form field, `data-transaction-line`, and `?line=`. "input" is too generic and collides with the HTML element. |
| Write verb, anchor day | `Transaction#stash`, `stashed_on` | The product's own verb. |
| Aggregation | `Spending`, `Month` | Plain business words. |
| Retry guard | `idempotency_key` | The word a reviewer already uses. |

**Indexes.**

| Index | Serves |
|---|---|
| `(user_id, occurred_on)` | Month windows |
| `(user_id, lower(name), occurred_on) WHERE discarded_at IS NULL` | Per-keystroke inference (2 ms budget) and the completions GROUP BY |
| unique `(user_id, idempotency_key)` | Create idempotency |

Ruby lookups use `downcase(:ascii)`, because SQLite's `lower()` folds ASCII only.

## Synthesis decision

Three runners produced candidates. Fable failed on usage credits and was rerun on opus.

- **C1 (opus):** keep `Stash`, anchor edits on `created_at`, one write verb, morph refresh.
- **C2 (opus):** rename to `Line`, pure grammar with resolution in a `before_validation`, a canonical-line printer for edits, server-declared undo, kept association, frame preview.
- **C3 (sonnet):** rename to `Draft`, JSON receipts for undo, `request_key` idempotency, morph refresh.

All three converged on the same core: a pure grammar inside one parser interface, `Time.use_zone`, a morph refresh instead of a streamed prepend, `Month` plus `Spending`, and three or four single-owner Stimulus controllers. That is a strong agreement signal.

**Base: C1.** A sonnet cross-judge scored it highest on the one-parser invariant (C1 5, C2 4, C3 2), and my own read agrees. Anchoring on `stashed_on` fixes date drift without changing what `line` stores and without a second printer. C2's canonical printer fails round-trip for names that contain grammar tokens (`7 eleven`) and silently recategorizes uncategorized rows. C3 leaves the drift in place.

**Grafted from C2:**

- The kept-only `has_many` plus `discarded_transactions`.
- The server-declared undo entry with `undo=1`. This replaced C1's client-built inverses, which needed route shapes and a `Location` header.
- `Turbo.visit(replace)` in place of C1's `turbo_stream.refresh`. C1 missed the 150 ms debounce; the judge flagged it and I confirmed it in the gem.
- The turbo-frame preview.

**Grafted from C3:**

- DB-level create idempotency (renamed `idempotency_key`).
- The `Draft` noun.
- A single write module (`support/write.js`, modeled on C3's `mutations.js`).

**Fixed in the base:** C1's PATCH could write to a discarded row. The kept association closes that. I also added `excluding:` to `Draft.parse`, so editing a row cannot infer its category from itself.

**Rejected:**

- C2's `before_validation` that reads the DB. Assigning an attribute that fires queries hides the read.
- C2's `Line#to_s` canonical printer.
- C3's `Statement` PORO. The month list is one query plus `group_by`.
- C3's JSON mutation responses. The change stream already carries the undo entry and the toast.

## Tradeoffs accepted

- We accept one extra GET plus a morph after every write (about 200-250 ms Enter to painted row) in exchange for no per-page stream code and figures that cannot go stale. The fallback if P5 perf fails is an optimistic row prepend inside `change.turbo_stream.erb`, which the morph then reconciles.
- We accept that relative words in an edit mean "relative to the day this row was stashed". Typing `yesterday` into an edit of a week-old row means the day before it was stashed. In exchange, edit and undo are exact.
- We accept that a repeated DELETE or restore returns 404 instead of a no-op 200. `write.js` reports it as "Already undone".
- We accept that the completions GROUP BY relies on SQLite's bare-column-with-`max()` behavior. Moving to Postgres would need a rewrite.
- We accept that a retried create whose row was discarded in the meantime hits the unique index and returns 409. This is rare and harmless.

## Alternatives considered

- **Targeted Turbo Streams per write**, as the spec has it. Each write gets a single round trip. But every write action would need to know every page's regions, and restore-in-place and cross-month stashes would each need their own rule. That leaks page layout into controllers and makes for a shallow interface.
- **A client-side JS copy of the parser.** It would be faster per keypress, but two parsers drift. It stays the named fallback only if the P5 perf gate fails (spec Appendix B).
- **A canonical absolute line for edits (C2).** It shows the user absolute dates, but it needs a printer that must round-trip the grammar. It breaks on names that contain tokens and on uncategorized rows.
- **Client-built undo (C1).** The client would carry route shapes and previous state, and a stale bar would undo to the wrong text.

## Open questions and risks

- **Spec deviations.** These need the operator's yes before the program arms, and quick-add.md should be amended to match:
  - The renames `Stash` → `Draft`, `input` → `line`, and `/stash/preview` → `GET /draft?line=`. P4's file becomes `app/models/draft.rb`.
  - The `idempotency_key` column and the third index.
  - Morph refresh instead of prepend.
  - `Month` lands in P5.
  - `User` gains the kept association in P3.
  - P5's file list changes: `drafts_controller.rb`, `drafts/` views, `support/write.js`, `transactions/change.turbo_stream.erb`.
- Does a 1500-row month list fit 200 ms in development mode, and can its morph fit the 300 ms delete/undo budget?
- Does idiomorph keep `aria-selected` and bar focus across a refresh? Spike this in P5 before P9 depends on it.
- Legacy rows from before P3 hold positive amounts that probably meant money out. Should P3 flip their sign, or keep them as lane 2 says?
- Should day totals on `/transactions` be money out only (this design) or net?

## Next implementation step

P3's `ShapeTransactions` migration and the kept association on `User`. Then P4's `Draft::Grammar.read` test table, with one literal case per grammar rule.
