---
name: verify-moneypouch
description: Drive the MoneyPouch Rails web app headless the way a user does. Boot on a chosen port, sign in as the seeded demo user, type, press keys, click, screenshot, resize, switch theme, and run read-only queries, one command each. Use to prove any UI behavior in this repo.
---

# verify-moneypouch

MoneyPouch is a Rails 8 app (SQLite, importmap, Tailwind). Its surface is a web UI. One script, `mp.mjs`, drives it through a headless Chrome over the DevTools protocol. It needs only Node 22+ (built-in `WebSocket`, `fetch`), Ruby, and a Chrome or Chromium binary. It has no npm dependencies.

Run everything from the repo root:

```
M=.claude/skills/verify-moneypouch/mp.mjs
```

Every command except `boot` and `query` takes `--port N`. With exactly one instance running the port is implied.

## Launch

```
$M boot --port 3101
```

Prints `http://localhost:3101/ port=3101 user=demo` once the app is signed in on the Overview. Without `--port`, `boot` reuses the single running instance, or takes the first free port from 3100 when none runs. With several running it asks for `--port`. Concurrent boots in one checkout serialize on `tmp/verify/setup.lock`.

`boot` is idempotent. A second call on the same port reuses the server and browser and prints the same URL. Two ports run side by side (separate server, separate Chrome profile). Both share the one development SQLite database, so writes from one show in the other.

What it does, in order: builds Tailwind once if `app/assets/builds/tailwind.css` is missing, `bin/rails db:prepare`, `bin/rails db:seed` (creates `demo` with `find_or_create_by!`), starts `bin/rails server` detached on the port, waits for `/up` to return 200, starts headless Chrome, signs in through the real form. It does not use `bin/dev`: foreman exits without a TTY because the Tailwind watcher dies. `.claude/launch.json` still runs `bin/dev` for humans.

A fresh clone needs only `bin/setup --skip-server` first (installs gems, prepares the database). Then `boot` works with no other step.

Per-instance state lives in `tmp/verify/<port>/` (gitignored): `state.json`, `server.log`, `chrome.log`, `holder.log`, the Chrome profile.

## Doctor

```
$M doctor --port 3101
```

Prints JSON with `serverAlive`, `chromeAlive`, `up` (the `/up` status), the current `url`, `theme`, and `viewport`. Exit 1 when the server is down or `/up` is not 200. Run it first whenever a drive behaves oddly. A port that is busy with a process this skill did not start makes `boot` refuse with an error instead of attaching.

## Drive

| Action | Command |
| --- | --- |
| Type into a field | `$M type '[aria-label="Quick add"]' 'coffee 5.50' --port N` (add `--clear` to replace). Types key by key, so keydown handlers fire. Prints the field value. |
| Press a key | `$M key Enter --port N`. Also `Escape`, `Tab`, `ArrowDown`, `Backspace`, a single character, `Meta+k`, `Shift+Tab`. |
| Click | `$M click 'button[data-theme="dark"]' --port N` |
| Screenshot | `$M shot /tmp/x/overview.png --port N` (`--full` for the whole page) |
| Resize viewport | `$M resize 375 812 --port N`. A small detached holder process per instance keeps the emulated viewport applied between commands, so the page does not see a resize until the next `resize`. Chrome headless cannot shrink its window below 500 px, which is why emulation is used. Prints `scrollWidth`; equal to the width means no horizontal scroll. |
| Switch theme | `$M theme dark --port N`. Real mouse click on the sidebar button, so the page must show the sidebar (`goto /` first). Waits for `html[data-theme]` and the `theme` cookie, and fails if the button is missing. |
| Navigate | `$M goto /session/new --port N` |
| Sign in or out | `$M signin demo wrong --port N`, `$M signout --port N` |
| Page text | `$M text '#alert' --port N` |
| Run JS | `$M js 'document.documentElement.dataset.theme' --port N` |
| Read-only query | `$M query 'Transaction.count'` |

Handles that exist today: quick add input `[aria-label="Quick add"]`, theme buttons `button[data-theme="light"|"dark"]`, sign-in fields `#username` and `#password`, flash `#alert` and `#notice`.

`query` evaluates the Ruby expression in `bin/rails runner` after reopening the database with SQLite `readonly: true`. `User.delete_all` and every other write fails with `SQLite3::ReadOnlyException`. The guard is the database connection, not a Ruby sandbox: `File.write` and `system` still run, so treat the expression as trusted input. It talks to the development database, so it needs no running instance.

The sign-in form is rate limited to 10 attempts per 3 minutes per client. A wrong-password drive costs one attempt.

## Evidence

- Screenshot every claim to a path you choose, for example `/tmp/<task>/owner/<slug>.png`, and look at the image. Evidence is the screenshot plus a number or string read back from the page (`type` prints the field value, `resize` prints `scrollWidth`, `theme` prints the attribute) plus `query` output for side effects.
- Drive the real path: `type` and `key` produce real key events, `click` real mouse events, sign-in uses the real form. Do not set values with `js` and call it typed.
- A key reaching the page is visible in the page, not in `log/development.log`, because key events are client side. Install a listener with `js` and read it back, or assert the visible result. Server requests an action triggers do show in `tmp/verify/<port>/server.log` and `log/development.log`.
- The browser console is not exposed. Read errors from `server.log`, or `js` with `window.onerror` capture installed before the action.

## Cleanup

```
$M stop --port 3101
```

Stops that instance's viewport holder, Chrome and Rails server by recorded pid and deletes `tmp/verify/<port>/`. It never kills by name. Screenshots you saved outside `tmp/verify/` survive. The development database and the `demo` user stay.

## Gotchas

- `bin/dev` and the plain `bin/rails server` both want `tmp/pids/server.pid`. `boot` uses `tmp/pids/verify-<port>.pid` so it can coexist with a human's `bin/dev` on 3000.
- Set `MP_CHROME` to a Chrome or Chromium binary when none is found in the default macOS and Linux locations.
- The Tailwind CSS is built once and not watched. After editing views with new utility classes, run `bin/rails tailwindcss:build` and reload with `goto`.
- A hung or failed `boot`: read `tmp/verify/<port>/server.log` and `chrome.log`.

Feature map: [features/README.md](features/README.md).
