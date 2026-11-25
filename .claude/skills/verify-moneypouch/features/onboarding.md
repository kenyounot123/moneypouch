# Onboarding

## Sub-features

- Create account at `/account/new`: username and password, `Create account ↵`. A taken or blank username re-renders the form with the error in `#alert` and the typed username kept.
- Every new user starts with one category, the built-in `Income` (`income: true`).
- On success the new user is signed in and lands on `/first_transaction`: the heading "What did you last spend on?" over `Type it on one line. A name and an amount are enough.`, the composer, and under it `Already have a history?` with `Import a file` (`/imports/new`) and `Connect a bank` (`/simplefin/access/new`), a divider, and `Skip for now` (to `/`). The three history links are left out in the demo. They stack on phones.
- The composer's preview under the field is four rows on this page, `div[data-reading=name|amount|date|category]`, each with a label, what was read, a hint, and a `.icon--check` on Name and Amount once read. Name reads the name in medium weight or `Required`, hint `The place or the thing`. Amount reads `$11.25` in `text-amount`, `+$2,400.00` in `text-success` for money in, or `Required`, hint `For money in, start with a plus:` and `+2400`. Date reads `Today`, `Yesterday` or `Sep 24`, in `text-date` once typed, hint `For another day, add` `yesterday` `or` `sep 26`. Category reads the name in `text-category` or `None yet`, hint `Add` `#food` `once. The same name gets it next time.` The hints hide below `sm`. After a 422 the message shows under the rows, in the same red with `animate-shake`. Inside `dialog#palette` the same partial shows the status line and the format line instead, see [voucher.md](voucher.md). The switch is CSS only, `in-[dialog]:`, so `GET /voucher` and the 422 stream render both.
- Adding a transaction there lands on the Overview with the row marked and the Undo toast. Skip for now lands on the Overview with no toast.
- `/first_transaction` redirects to `/` once the user has a kept transaction.
- A new account (not a sandbox) starts with the Get started list showing on the Overview, see [overview.md](overview.md). Existing accounts were migrated with it hidden (`users.get_started_hidden`, default false after the migration).
- Registration closes after the first account. `/account/new` then redirects to `/session/new` with the alert `Registration is closed.`, and the sign-in page has no Create account link. The owner (the oldest account, `demo` only in a fresh database; check with `$M query 'User.owner.username'`) reopens it in Settings, Account, New accounts: `Open registration` or `Close registration` (`form[action="/registration"] button`, `PATCH /registration`, saved on the owner's `users.registration_open`), beside `Anyone who can reach this server can create an account.` or `Registration is closed. Only existing accounts can sign in.` A non-owner gets 403. Creating an account is rate limited like sign-in.

## How to get to it (user POV)

A fresh server: open `/`, which goes to `/session/new`, which goes to `/account/new` while no users exist. Otherwise, once the owner has opened registration, click "Create account" under the sign-in form.

## Driving it with mp.mjs

- Open registration first: `mp.mjs goto /settings --port N`, `mp.mjs click 'form[action="/registration"] button' --port N`, `mp.mjs wait main --text 'Close registration' --port N`. `mp.mjs query 'User.registration_open?'` prints `true`. Close it the same way when done, then wait for `Open registration`.
- `mp.mjs signout --port N`, then `mp.mjs goto /account/new --port N`.
- `mp.mjs type '#user_username' name --port N`, `mp.mjs type '#user_password' secret --port N`, `mp.mjs key Enter --port N`. The URL is then `/first_transaction`.
- `mp.mjs type '[aria-label="Add"]' 'tea 3' --port N`, `mp.mjs key Enter --port N`, `mp.mjs wait '[id^=toast_transaction]' --port N` prints the toast text on the Overview.
- Duplicate username: `mp.mjs text '#alert' --port N` prints `Username has already been taken`.
- Clean up with `bin/rails runner`, since `query` is read-only. `User` has no `dependent:` on transactions, so delete them first, discarded ones included: `bin/rails runner 'u = User.find_by!(username: "name"); Transaction.unscoped.where(user_id: u.id).delete_all; u.destroy!'`.

## Gotchas

- The dev database is shared and has the `demo` user, so the no-users redirect only shows on an empty database, and Create account only works after Open registration.
- Accounts made while driving persist in the dev database. Delete them when done.
- The first transaction page renders the composer inline, with no palette, so `type` works there without `key Meta+k`. The field looks the same as inside the Overview's palette, minus the `esc` chip, and the preview is the four rows. The `#` list and the `@` calendar open below the panel and over the history links.
- Read the rows with `mp.mjs text '[data-reading=amount]' --port N` after `mp.mjs wait 'turbo-frame#voucher' --text '$11.25' --port N`. The error after Enter on `coffee`: `mp.mjs text 'turbo-frame#voucher p.animate-shake' --port N` reads `Type an amount, like 5.50`. `mp.mjs signin newname password` signs the new user in without the registration switch.
