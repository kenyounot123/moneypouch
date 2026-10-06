# Sign in

## Sub-features

- Sign in with a valid username and password, landing on the Overview.
- Wrong credentials redirect back to `/session/new` with the alert "Try another username or password."
- Sign out destroys the session and lands on `/session/new`.
- A fresh server with no users sends `/session/new` to `/account/new`, see [onboarding.md](onboarding.md).
- The sign-in page links to Create account and ends with the footnote "Your data never leaves your computer".
- Sign out is a button in the Account section of `/settings`.

## How to get to it (user POV)

Open `/`. Without a session the app redirects to `/session/new`.

## Driving it with mp.mjs

- `mp.mjs signout --port N`, then `mp.mjs signin demo <password> --port N`. The `demo` password is `demo-password`, set in `db/seeds.rb`. `boot` already signs in.
- Wrong password: `mp.mjs signin demo wrong --port N`, then `mp.mjs text '#alert' --port N` prints the alert. Screenshot with `shot`.
- Proof of success is the printed URL `http://localhost:N/` and a screenshot showing the sidebar.

## Gotchas

- Sign-in is rate limited to 10 attempts per 3 minutes. The alert then reads "Try again later."
- After a wrong password the browser stays signed out. Run `mp.mjs boot --port N` to sign back in.
