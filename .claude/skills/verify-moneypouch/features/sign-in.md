# Sign in

## Sub-features

- Sign in with a valid username and password, landing on the Overview.
- Wrong credentials redirect back to `/session/new` with the alert "Try another username or password."
- Sign out destroys the session and lands on `/session/new`.
- A fresh server with no users sends `/session/new` to `/account/new`, see [onboarding.md](onboarding.md).
- The sign-in page reads `Welcome back` and `Sign in to your pouch.`, shows `New here? Create account` only while registration is open (see [onboarding.md](onboarding.md)), then a `Forgot your password?` disclosure (see [password-reset.md](password-reset.md)), and ends with the footnote "Your data never leaves your computer". After a wrong password the pouch looks worried.
- In demo mode the page offers `Try MoneyPouch` instead of the form, see [demo.md](demo.md).
- A signed-out visit to any page sends you to sign in and remembers the page, so signing in returns there instead of the Overview.
- Sign out is a button in the Account section of `/settings`, `form[action="/session"] button`. `mp.mjs signout` sends `DELETE /session` with `fetch` instead, so click the button to prove it.

## How to get to it (user POV)

Open `/`. Without a session the app redirects to `/session/new`.

## Driving it with mp.mjs

- `mp.mjs signout --port N`, then `mp.mjs signin demo <password> --port N`. The `demo` password is `demo-password`, set in `db/seeds.rb`. `boot` already signs in.
- Wrong password: `mp.mjs signout --port N` first, because `signin` does nothing while a session is active. Then `mp.mjs signin demo wrong --port N`, then `mp.mjs text '#alert' --port N` prints the alert. Screenshot with `shot`.
- Proof of success is the printed URL `http://localhost:N/` and a screenshot showing the sidebar.
- Return to the page you asked for: `mp.mjs signout --port N`, `mp.mjs goto /settings --port N` (lands on `/session/new`), `mp.mjs type '#username' demo --port N`, `mp.mjs type '#password' demo-password --port N`, `mp.mjs key Enter --port N`, then `mp.mjs wait h1 --text Settings --port N`. `signin` can't show this, because it opens `/` first.

## Gotchas

- Sign-in is rate limited to 10 attempts per 3 minutes. The alert then reads "Try again later."
- After a wrong password the browser stays signed out. Run `mp.mjs boot --port N` to sign back in.
