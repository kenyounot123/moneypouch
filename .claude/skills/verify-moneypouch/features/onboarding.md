# Onboarding

## Sub-features

- Create account at `/account/new`: username and password, `Create account ↵`. A taken or blank username re-renders the form with the error in `#alert` and the typed username kept.
- On success the new user is signed in and lands on `/first_transaction`: the heading "What did you last spend on?", the composer, the hint "Only the name and amount are required", and a "Skip for now" link to `/`.
- Adding a transaction there lands on the Overview with the row marked and the Undo toast. Skip for now lands on the Overview with no toast.
- `/first_transaction` redirects to `/` once the user has a kept transaction.
- Open sign-up: anyone can create an account. The page is rate limited like sign-in.

## How to get to it (user POV)

A fresh server: open `/`, which goes to `/session/new`, which goes to `/account/new` while no users exist. Otherwise click "Create account" under the sign-in form.

## Driving it with mp.mjs

- `mp.mjs signout --port N`, then `mp.mjs goto /account/new --port N`.
- `mp.mjs type '#user_username' name --port N`, `mp.mjs type '#user_password' secret --port N`, `mp.mjs key Enter --port N`. The URL is then `/first_transaction`.
- `mp.mjs type '[aria-label="Add"]' 'tea 3' --port N`, `mp.mjs key Enter --port N`, `mp.mjs wait '[id^=toast_transaction]' --port N` prints the toast text on the Overview.
- Duplicate username: `mp.mjs text '#alert' --port N` prints `Username has already been taken`.
- Clean up: `bin/rails runner` to delete the test user and its rows, since `query` is read-only.

## Gotchas

- The dev database is shared and has the `demo` user, so the no-users redirect only shows on an empty database.
- Accounts made while driving persist in the dev database. Delete them when done.
- The first transaction page has no sidebar and sits on the page background, so the voucher tray looks the same as on the Overview.
