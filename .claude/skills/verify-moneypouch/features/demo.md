# Demo mode

## Sub-features

- `MONEYPOUCH_DEMO=true` turns demo mode on. `config.x.demo` in `config/application.rb` reads it, and nothing else reads the env var. Off, the app behaves as it always has.
- The sign-in page reads `Welcome to MoneyPouch`, one line saying the visitor gets a private sandbox with a year of sample spending that is deleted after 24 hours, a `Try MoneyPouch` button (`form[action="/sandbox"] button`), and `Like it? Install MoneyPouch on your own computer.` There is no username or password form, no `Forgot your password?`, and no `Create account`.
- `Try MoneyPouch` posts to `/sandbox`, which creates a sandbox (`User.create_sandbox`: a `visitor-…` account with `expires_at` 24 hours out, 300 everyday purchases plus a year of monthly bills and twice-monthly paychecks), signs it in, and lands on the Overview. It is limited to 5 per 10 minutes per IP and answers 404 outside the demo.
- A sandbox never counts as the owner (`User.owner` skips rows with `expires_at`), and registration is closed in the demo, so `/account/new` redirects to sign in, even on a server with no accounts.
- A note in the sidebar's foot, or under the top bar below `md`, reads `This is a demo`, `Your sandbox is deleted in 24 hours.` (whole hours, then minutes), and links `Install MoneyPouch` and `Send feedback`. It is `section[aria-label=Demo]`, hidden while the sidebar is collapsed.
- Bank sync, Import, password reset links and pages, and the registration switch answer 404 in the demo. Settings' Bank sync section and the empty Overview show `Not available in the demo` where Connect and Import were, and the sidebar has no Import link.
- `User.delete_expired_sandboxes` runs hourly from `config/recurring.yml` in production and deletes each expired sandbox with every row it owns, deleted transactions and bank rows included.

## How to get to it (user POV)

Open the demo server's `/`. Signed out, it goes to `/session/new`, which shows `Try MoneyPouch`.

## Driving it with mp.mjs

- `boot` signs in through the form, which the demo hides, so boot with demo mode off first, then restart only the server with it on: `mp.mjs server stop --port N`, `MONEYPOUCH_DEMO=true mp.mjs server start --port N`. The server inherits the environment of the `mp.mjs` that starts it.
- Then `mp.mjs signout --port N`, `mp.mjs goto /session/new --port N`, `mp.mjs click 'form[action="/sandbox"] button' --port N`, `mp.mjs wait 'aside#sidebar' --port N`.
- Back to normal: `mp.mjs server stop --port N`, `mp.mjs server start --port N` without the variable, and `mp.mjs boot --port N` to sign in as `demo` again.
- Count sandboxes with `mp.mjs query 'User.sandboxes.count'`.

## Gotchas

- Each `Try MoneyPouch` click makes a new sandbox in the development database. They stay until `User.delete_expired_sandboxes` runs after they expire, which only the production recurring schedule does on its own.
- The rate limit counts in the cache store. Development uses the memory store, so restarting the server resets it.
