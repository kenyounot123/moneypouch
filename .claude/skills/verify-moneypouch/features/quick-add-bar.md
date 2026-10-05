# Quick add bar

Status: Q1 and Q2 built. Q3 to Q5 are planned. The change that builds a part replaces its "planned" notes with what it actually built, including any handle it renamed.

## Sub-features

- Q1, preview. Built. The bar is `app/views/shared/_quick_add.html.erb` under `data-controller="quick-add"` (`app/javascript/controllers/quick_add_controller.js`). On `input`, `keyup`, and `click` the controller derives `/draft?line=...` from the field and sets `turbo-frame#draft`'s `src` only when that URL changes, so Turbo cancels a stale request and only the latest line paints. `DraftsController#show` renders `app/views/drafts/_draft.html.erb`: a preview row shaped like a Recent row, then the legend `5.50` amount, `@` date, `#` category. A used part gets the gold chip and a check. The amount part turns red while the line is not empty and has no amount. An empty line shows only the legend (`turbo-frame#draft > div` count 1). A missing name or amount shows a red callout, `Type a name, like coffee` or `Type an amount, like 5.50`. A typed `+` shows `+$2,400.00` in green with `Money in` under it. An unsaved category shows `(new)`, no category shows `Uncategorized`. Dates read Today, Yesterday, `Sep 24`, or `Sep 24, 2025`. The row carries `data-inferred-category="<name>"` when the category came from history, and no attribute otherwise. `time_zone_controller.js` on `<html>` writes the `time_zone` cookie, and `ApplicationController` wraps each request in `Time.use_zone`, falling back to UTC.
- Q2, add and undo. Built. The bar is a `form_with url: transactions_path` holding `input[name=line]` and a hidden `input[name=idempotency_key]` with a fresh `SecureRandom.uuid` per render. Enter or `Add ↵` always posts. `TransactionsController#create` parses the line with `Transaction::Draft`. A valid line goes through `create_or_find_by!` on the key within the user's transactions, so a repeated key returns the existing row, then redirects back with `303`. `turbo_refreshes_with method: :morph, scroll: :preserve` turns that into a morph refresh: the field empties, focus stays in it, and Recent updates. An invalid line answers `422` with a turbo stream that replaces `turbo-frame#draft` with the same draft whose callouts and red legend chip carry `animate-shake`; the text stays and nothing is created. The toast is `[data-controller="toast"]` with id `toast_transaction_<id>`, text `Added <name> <amount>`, and an Undo `button_to` marked `[data-quick-add-target="undo"]` that sends `DELETE /transactions/:id`. Its hint reads `⌘Z` when the user agent says Macintosh (headless Chrome on macOS does) and `Ctrl Z` otherwise. `toast_controller.js` fades it at 4.8 s and removes it at 5 s. `⌘Z` or `Ctrl+Z` in the empty field clicks that button while it exists. `destroy` calls `Transaction#discard` and redirects back with the row's `line` in the flash, which the bar renders as the field value with its draft. Recent shows the 5 latest kept rows by `occurred_on` then `id`, the added one with the gold marker, under `<count> this month`, or `Nothing yet. Type a line above.` when there are none. A request from the bar's form that fails (the server is down, or any response other than success and the 422 stream) puts `[data-failure]` at the top of `turbo-frame#draft` with the callout `Not saved. Press Enter to try again.` The text and the `idempotency_key` stay, so the retry creates exactly one row. The next input removes the callout.
- Q3, Tab completion. `GET /completions` lists the user's kept names. Typing `Tra` shows `der Joe's` dimmed with a `Tab` chip, and Tab writes `Trader Joe's `.
- Q4, `#` category list. The field becomes `role="combobox"` with `aria-expanded`. Options are `role="option"` with one `aria-selected="true"`. The inferred category comes first. An unknown word ends the list with `New category <word>`.
- Q5, `@` calendar. A `role="grid"` month opens under the bar. Arrows move by day or week, PageUp and PageDown by month, `t` picks today, `y` yesterday, Tab, Enter, or a click picks the cursor's date, and Esc removes the `@`.

## How to get to it (user POV)

Sign in, land on `/`, and type into the bar at the top. Everything happens in that one field with the keyboard. The only other surfaces are Recent on the same page, the toast, and `/transactions` for discarding a row.

## Driving it with mp.mjs

Boot per the plan's boot recipe: `bin/setup --skip-server`, `bin/rails "dev:transactions[100]"`, `$M boot --port <free port>`. History matters: completion and inference need names such as `Trader Joe's`, `Spotify`, and `Lyft`.

Read the preview after every keystroke batch. `type` returns before the server answers, so wait on the text you expect before a `shot`:

```
$M type '[aria-label="Quick add"]' 'Spotify yesterday' --port N
$M wait 'turbo-frame#draft' --text 'Type an amount, like 5.50' --port N
$M shot /tmp/swarm-q1/worker-1/preview.png --port N
```

Lane recipes by kind:

- Word by word (Q1 lane 2). Call `type` once per word and `wait` plus `shot` after each. A second `type` appends at the caret.
- Fast typing, latest wins (Q1 lane 10). One `type` call sends 20 characters in well under 100 ms. Then `$M wait 'turbo-frame#draft:not([busy])' --port N` and compare the row text with the field value from `$M js 'document.querySelector("[aria-label=\"Quick add\"]").value'`. To prove no stale row painted after it, install a `turbo:frame-render` counter with `js` before typing and read the frame text at each render.
- Side effects (Q1 lane 4, Q2 lanes 1 to 8, Q5 lane 7). Read `$M query 'Category.count'` and `$M query 'User.find_by!(username: "demo").transactions.count'` before and after. For a saved row, use `$M query 'Transaction.order(:id).last.attributes'`, which includes discarded rows. For undo, check that `discarded_at` is set. The query is read-only, so it cannot change the result.
- Triple Enter (Q2 lane 3). `$M key Enter Enter Enter --port N` sends three presses under 1 ms apart, then compare the count.
- Undo (Q2 lanes 4 and 5). `$M key Meta+z --port N` on macOS, or `Ctrl+z`. For the expired case, run `sleep 6` in the shell between the add and the key.
- Dropped server (Q2 lane 8). Type a line, `$M server stop`, `$M key Enter`, `$M shot`, check the field still holds the text, `$M server start`, `$M key Enter`, and check the count went up by exactly one.
- Caret in the middle (Q3 lane 5, Q4 lane 6). `$M key ArrowLeft ArrowLeft` moves the caret. Read it back with `$M js 'document.activeElement.selectionStart'`.
- Popups (Q4, Q5). `$M key ArrowDown ArrowDown Enter`, `$M key PageUp Tab`, `$M key Escape`. Read ARIA with `$M js '[document.activeElement.getAttribute("aria-expanded"), document.querySelectorAll("[role=option][aria-selected=true]").length]'`. Click an option with `$M click '[role="option"]:nth-child(2)'`.
- Time zone (Q1 lane 7). `$M zone Pacific/Kiritimati`, `$M goto /`, type `tea 3 today`, and compare with `$M query 'Time.use_zone("Pacific/Kiritimati") { Date.current }'`. Finish with `$M zone off`. Setting the cookie with `js` instead gets overwritten when `time_zone_controller.js` connects on reload.
- Phone and dark (lanes 8 to 10). `$M resize 375 812` prints `scrollWidth`, which must equal 375. Run `$M theme dark` before typing, because the theme button reloads the page and empties the field.
- Trunk regression (lane 1 of each Q). Use the two-checkout recipe in `SKILL.md`, and drive trunk with trunk's own `mp.mjs`.

Perf blocks, at least 20 samples each, one key per `latency` call:

- Q1 preview: `$M latency <char> --end turbo:frame-render --log lat.jsonl` per character, after `bin/rails "dev:transactions[10000]"`. Budget p95 ≤ 100 ms.
- Q2 add and undo: type a valid line, then `$M latency Enter --end turbo:morph --log add.jsonl`. Then `$M latency Meta+z --end turbo:morph --log undo.jsonl`. Budget p95 ≤ 300 ms each.
- Q3 remainder: `--end turbo:frame-render`, the same as Q1, because the remainder comes back through the frame. Budget p95 ≤ 100 ms. Read `GET /completions` times from `tmp/verify/N/server.log` `Completed ... in Xms` lines.
- Q4 list and Q5 calendar: `--end paint`, because no server is involved. Budget p95 ≤ 16 ms.
- Report with `$M latency --report lat.jsonl`.

Review video: `$M record start /tmp/QN-review/review.mp4`, drive with `type --delay 90`, then `$M record stop`.

## Gotchas

- Every handle here comes from the plan, not from code. If a lane cannot find `turbo-frame#draft` or `[role="option"]`, read the PR's views before reporting a failure.
- Planned error text is `Type an amount, like 5.50` and `Type a name, like coffee`. Until Q1, `Transaction::Draft` still says `Add an amount` and `Add a name`.
- The toast lives 5 seconds. Chain the add and `$M key Meta+z` in one shell line; reading a screenshot between them can outlast it.
- `wait` with only a selector can pass on the previous render. Always pass `--text` with what the new render must contain, or wait on `:not([busy])` after the frame has gone busy.
- `--end paint` in `latency` measures to the frame after the keydown task. It cannot tell whether the popup changed in that frame. Pair it with a `shot` that shows the change.
- `dev:transactions` adds rows on each run, and every lane in one checkout shares one database. Read counts as before-and-after differences, not as absolute numbers.
