# Bank sync

## Sub-features

- The Bank sync section on `/settings`, inside `turbo-frame#bank_sync`, between Appearance and Account. Its state follows `Simplefin::Access#status`: none or `disconnected` shows Connect a bank, `pending` shows the account picker, `active` shows the synced accounts, `revoked` shows Reconnect. `Simplefin::Access#lapsed?` reads the latest answered `Simplefin::Sync` (finished with no failure, `lapsed`, or `revoked`, so an `unavailable` or `abandoned` sync does not hide it) and adds the subscription notice.
- Connect: `GET /simplefin/access/new` in the frame. Pasting a SimpleFIN setup token into `#simplefin_access_setup_token` submits the form (`paste-submit` Stimulus controller, on `input` with `inputType` `insertFromPaste`). Typing does not submit; Enter does.
- Pick: checkboxes `simplefin_access[account_ids][]`, the Start from radios `simplefin_access[history]` (`today` or `90_days`), and `Start syncing ↵` (`button.bg-action`), which sends `PATCH /simplefin/access` and queues `Simplefin::SyncJob`.
- Steady state: `Synced N min ago` with `Sync now` (`POST /simplefin/sync`), one row per synced `BankAccount` with its bank transaction count, New rows with Skip and Sync it (`PATCH /bank_accounts/:id`), and Disconnect (`DELETE /simplefin/access`). An account with a SimpleFIN error shows SimpleFIN's own message and Fix on SimpleFIN.
- Rows: every `transactions/_transaction` row has a right slot `div.w-4`. Rows with a `BankTransaction` show the bank icon with `span.sr-only` "From your bank". Imported rows with no category show the left `div.bg-highlight` marker; rows matched to a typed transaction do not.
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
