# Password reset

## Sub-features

- The owner's Account section in `/settings` lists every other account with a "Reset link" button, `form[action="/users/ID/password_reset"] button`. The list is hidden when there are no other accounts.
- Clicking it returns to `/settings` with a read-only field `#reset_link`, the text "It works once and expires in 24 hours", and a Copy button that reads "Copied" for two seconds.
- The link opens `/passwords/TOKEN/edit`, "Choose a new password" with the username. Submitting matching passwords redirects to `/session/new` with the notice "Password changed. Sign in with your new password."
- A used, expired, or made-up link redirects to `/session/new` with the alert "That reset link has expired or was already used."
- Mismatched or blank passwords re-render the page with the error and status 422.
- A reset signs the account out on every device.
- A non-owner gets 403 from the Reset link endpoint, and so does the owner for their own account.
- `/session/new` has a "Forgot your password?" disclosure that points to the owner and the README.
- `bin/rails password:reset` resets from the command line. It prompts for a username (Enter picks the owner), then the password and confirmation, and also reads them from piped stdin.

## How to get to it (user POV)

Sign in as the owner, open Settings, click Reset link beside another account, and copy the link. Open it in a signed-out browser.

## Driving it with mp.mjs

- Needs a second account. Sign out, create one at `/account/new` after opening registration (see [onboarding.md](onboarding.md)), or from `bin/rails console`, then `mp.mjs boot --port N` to sign back in as the owner.
- `mp.mjs click 'form[action$="/password_reset"] button' --port N`, then `mp.mjs js 'document.querySelector("#reset_link").value' --port N` prints the link, because `text` does not read input values. Screenshot with `shot`.
- Proof of success is the sign-in page showing `#notice`, then `signin` with the new password reaching `http://localhost:N/`.
- CLI: `printf 'demo\nnew-pass\nnew-pass\n' | bin/rails password:reset` prints "Password changed for demo. Every device is signed out."

## Gotchas

- The link is in the flash, so it shows once. Reloading Settings hides it. Click Reset link again for a new one, and the old one still works until used or expired.
- The reset page is rate limited to 10 submits per 3 minutes.
