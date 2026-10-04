# Add a transaction

## Sub-features

- Quick add bar on the Overview: the `Quick add` input, three read-back pills, and the `Add ↵` button.
- `/transactions` lists the user's kept transactions, each with a Destroy button.
- `bin/rails "dev:transactions[N]"` adds N realistic rows for `demo` across the last 12 months.

## How to get to it (user POV)

Sign in. The quick add bar sits at the top of `/`. Type a line such as `coffee 5.50 yesterday`, then press Enter or click `Add ↵`. The sidebar's Transactions link opens `/transactions`.

## Driving it with mp.mjs

- Count before: `mp.mjs query 'User.find_by!(username: "demo").transactions.count'`.
- Note the server log length: `L=$(wc -l < tmp/verify/N/server.log)`.
- `mp.mjs type '[aria-label="Quick add"]' 'coffee 5.50 yesterday' --port N` prints the field value.
- `mp.mjs key Enter --port N`, then `mp.mjs click 'main button[type="button"]' --port N` for the button.
- Requests the add sent: `tail -n +$((L+1)) tmp/verify/N/server.log | grep -E 'Started|Completed'`.
- Count after with the same `query`. Screenshot with `shot`.
- The proof of a working add is all three: a `POST /transactions` in the log, the count up by one, and a row with `name`, `amount_in_cents`, `occurred_on`, and `line` from `mp.mjs query 'User.find_by!(username: "demo").transactions.order(:id).last.attributes'`.
- Bulk data for list and Overview drives: `bin/rails "dev:transactions[100]"`. It prints the new total for `demo`.

## Gotchas

- Today the add is not wired. Enter and `Add ↵` send no request, the field keeps its text, and the count stays the same. A drive that shows this is reporting the current state, not a regression.
- The pills `$5.50`, `Food`, and `Sep 26` are static markup and do not follow the typed line. They are hidden below 640 px wide.
- `TransactionsController#create` only permits `amount_in_cents` and `currency`, so a direct `POST /transactions` fails the NOT NULL `name` and `occurred_on` columns. No page posts to it.
- `/transactions` renders an empty `_transaction` partial, so each row shows only its Destroy button. Count rows with `mp.mjs js 'document.querySelectorAll("#transactions > div").length' --port N`. Destroy hard-deletes the row from the shared development database.
- `User#transactions` returns kept rows only. Count discarded rows with `User#discarded_transactions`.
- `dev:transactions` writes to the development database every instance shares, and repeated runs add rows. It loads the seed first, so it also resets the `demo` password.
