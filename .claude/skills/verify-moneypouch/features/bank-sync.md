# Bank sync

## Sub-features

- The Bank sync section on `/settings`, inside `turbo-frame#bank_sync`, between Appearance and Account. Its state follows `Simplefin::Access#status`: none or `disconnected` shows Connect a bank, `pending` shows the account picker, `active` shows the synced accounts, `revoked` shows Reconnect. `Simplefin::Access#lapsed?` reads the latest answered `Simplefin::Sync` (finished with no failure, `lapsed`, or `revoked`, so an `unavailable` or `abandoned` sync does not hide it) and adds the subscription notice.
- Connect: `GET /simplefin/access/new` in the frame. Pasting a SimpleFIN setup token into `#simplefin_access_setup_token` submits the form (`paste-submit` Stimulus controller, on `input` with `inputType` `insertFromPaste`). Typing does not submit; Enter does.
- Pick: checkboxes `simplefin_access[account_ids][]`, the Start from radios `simplefin_access[history]` (`today` or `90_days`), and `Start syncing ↵` (`button.bg-action`), which sends `PATCH /simplefin/access` and queues `Simplefin::SyncJob`.
- Steady state: `Synced N min ago` with `Sync now` (`POST /simplefin/sync`), one row per synced `BankAccount` with its bank transaction count, New rows with Skip and Sync it (`PATCH /bank_accounts/:id`), and Disconnect (`DELETE /simplefin/access`). An account with a SimpleFIN error shows SimpleFIN's own message and Fix on SimpleFIN.
- Names: `BankTransaction::Name` turns SimpleFIN's `payee` and `description` into the transaction name (Zelle prefix and trailing reference codes dropped, the description used when the payee only says "Zelle Transfer") and the `bank_transactions.name_key` it stores for matching repeats. The demo's names are already clean, so its keys are `grocery store`, `johns fishin shack`, `you`.
- Rows: every `transactions/_transaction` row has a right slot `div.w-4`. Rows with a `BankTransaction` show the bank icon with `span.sr-only` "From your bank". Imported rows with no category show the left `div.bg-highlight` marker; rows matched to a typed transaction do not.
- Category editing: every row's category (or "Uncategorized") is a `button[data-action="category-picker#open"]`. `category_picker_controller.js` sits on Recent's `ul` and on `ul#transactions` with `data-category-picker-categories-value`, and puts one form in the clicked row's category line: `input[aria-label=Category][role=combobox]` and `#category-picker-list[role=listbox]` with `#category-picker-option-<n>` options filtered by prefix, plus `New category <word>`. Up and Down move, Tab completes, Enter or a click saves through `PATCH /transactions/:id/categorization` (`categorization[category]`, a name; blank clears; a new name creates the category), Escape closes and refocuses the button, blur closes without saving. The list ends with `Transfer` (hint `Not spending`, after a divider) whenever the typed text is a prefix of "transfer"; it posts `categorization[transfer]=1`. A transfer row reads `Transfer · <date>`, has its name and amount in `text-tertiary`, shows the ⇄ icon with `span.sr-only` "Transfer, not spending" in place of the bank icon, has no marker, and is left out of `Transaction.spending`, so the hero total and "Where it went" drop by its amount. The page morphs after the redirect, so "Where it went" and the marker update.
- Rules: picking a category or Transfer on an imported row (not a typed or matched one, and not a blank pick) saves a `BankAccount::Rule` for that bank account and `name_key`, then `apply_to_uncategorized` fills that account's same-name imported rows that still need a category. It never overwrites a category or a transfer, and another account's rows are untouched. Imports take the rule's categorization first and fall back to the last category used for the name. Proof: `mp.mjs query 'BankAccount.all.map { |a| [a.name, a.transactions_named("grocery store").group(:category_id, :transfer).count, a.rules.map { [_1.name_key, _1.category&.name] }] }'`. To watch an import pick up a rule, delete one imported bank row and its transaction with `bin/rails runner`, then Sync now.
- Toast: the Overview and `/transactions` show `[id^=toast_simplefin_sync]` for the latest sync that brought bank transactions, once. It sets the `simplefin_sync_seen` cookie. `Show new` opens `/transactions?sync=ID`.

## How to get to it (user POV)

Sidebar, Settings, Bank sync, Connect a bank. Open SimpleFIN, copy a setup token, paste it. Pick accounts, choose Today or 90 days ago, Start syncing. Settings flips from `Syncing…` to `Synced just now` by itself when the job finishes.

## Driving it with mp.mjs

- A demo token: `curl -s https://beta-bridge.simplefin.org/info/developers | grep -oE 'aHR0[A-Za-z0-9+/=]{60,}' | sort -u`. Each token claims once. A reload of that page gives a new one.
- `mp.mjs goto /settings --port N`, `mp.mjs click 'turbo-frame#bank_sync a' --port N`, `mp.mjs wait 'turbo-frame#bank_sync' --text 'Paste it here' --port N`.
- `mp.mjs paste '#simplefin_access_setup_token' "$TOKEN" --port N`, then `mp.mjs wait 'turbo-frame#bank_sync' --text 'Pick the accounts' --timeout 20000 --port N`. Paste the same token again for the rejected state: `--text 'already used'`.
- Choose 90 days: `mp.mjs click 'label:has(input[value="90_days"])' --port N`. Start: `mp.mjs click 'turbo-frame#bank_sync button.bg-action' --port N`, then `mp.mjs wait 'turbo-frame#bank_sync' --text 'Synced just now' --timeout 30000 --port N`.
- Proof of an import: `mp.mjs query 's = Simplefin::Sync.last; [s.failure, s.imported_count, s.matched_count]'` and `mp.mjs query '[Transaction.count, BankTransaction.count]'`. The demo gives about 170 transactions per account for 90 days.
- Sync now: `mp.mjs click 'turbo-frame#bank_sync form[action="/simplefin/sync"] button' --port N`, poll `Simplefin::Sync.finished.count` until it grows, and compare the counts. A second sync of the same data adds 0 rows.
- Disconnect: `mp.mjs click 'turbo-frame#bank_sync form[action="/simplefin/access"] button' --port N`. Transactions and bank transactions stay.

## Gotchas

- In the picker, Cancel is also a submit button in the frame and disconnects. Target `button.bg-action` for Start syncing, never `button[type=submit]`.
- The demo has no 402, 403, or errlist states. To look at the lapsed notice, run `Simplefin::Sync.last.update_column(:failure, "lapsed")` with `bin/rails runner`, take the shot, and set it back to `nil`. To look at `revoked`, set `Simplefin::Access.sole.update_column(:status, "revoked")` and back to `active`. Do not clear `access_url`, or you need a new token.
- The demo dates some transactions a day or two in the future, so the newest bank rows can sit after today.
- Development runs jobs with the in-process async adapter, so a sync runs inside the server a moment after the request. The recurring hourly sweep (`Simplefin::Access.sync_due`) is only scheduled in production.
- Jobs read the time zone from `users.time_zone`, which any signed-in request saves from the `time_zone` cookie.
- The toast shows once per sync per browser. Reset it with `mp.mjs js 'document.cookie = "simplefin_sync_seen=0; path=/"' --port N` before `goto`.
