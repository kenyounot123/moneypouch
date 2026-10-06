# Add a transaction

## Sub-features

- Composer on the Overview: the `Add` input, the `Add ↵` button, and the preview frame `turbo-frame#voucher` (under them below `lg`, above them at `lg` and up).
- Enter or `Add ↵` posts the shorthand to `POST /transactions`, see [composer.md](composer.md) for the toast and undo.
- `/transactions` lists the user's kept transactions as `ul#transactions > li`, newest `occurred_on` first, each with a Delete button that discards the row.
- `bin/rails "dev:transactions[N]"` adds N realistic rows for `demo` across the last 12 months.

## How to get to it (user POV)

Sign in. The composer sits at the top of `/`. Type shorthand such as `coffee 5.50 yesterday`, then press Enter or click `Add ↵`. The sidebar's Transactions link opens `/transactions`.

## Driving it with mp.mjs

- Count before: `mp.mjs query 'User.find_by!(username: "demo").transactions.count'`.
- Note the server log length: `L=$(wc -l < tmp/verify/N/server.log)`.
- `mp.mjs type '[aria-label="Add"]' 'coffee 5.50 yesterday' --port N` prints the field value.
- `mp.mjs key Enter --port N`, or `mp.mjs click 'form[action="/transactions"] button' --port N` for the button.
- Requests the add sent: `tail -n +$((L+1)) tmp/verify/N/server.log | grep -E 'Started|Completed'`.
- Count after with the same `query`. Screenshot with `shot`.
- The proof of a working add is all three: a `POST /transactions` in the log, the count up by one, and a row with `name`, `amount_in_cents`, `occurred_on`, and `shorthand` from `mp.mjs query 'User.find_by!(username: "demo").transactions.order(:id).last.attributes'`.
- Bulk data for list and Overview drives: `bin/rails "dev:transactions[100]"`. It prints the new total for `demo`.

## Gotchas

- Invalid shorthand answers `422` and saves nothing, so a `POST /transactions` in the log is not proof of an add. Check the count.
- `TransactionsController#create` takes `shorthand` and `idempotency_key`. A second post with the same key returns the first row.
- `/transactions` renders each row with `transactions/_transaction.html.erb`, the same `<li>` Recent uses. Count rows with `mp.mjs js 'document.querySelectorAll("#transactions > li").length' --port N`. Delete discards the row (sets `discarded_at`), so `Transaction.count` stays the same.
- `User#transactions` returns kept rows only. Count discarded rows with `User#discarded_transactions`.
- `dev:transactions` writes to the development database every instance shares, and repeated runs add rows. It loads the seed first, so it also resets the `demo` password.
