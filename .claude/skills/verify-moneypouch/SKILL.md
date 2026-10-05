---
name: verify-moneypouch
description: Drive the MoneyPouch Rails web app headless the way a user does. Boot on a chosen port, sign in as the seeded demo user, type, press keys, click, wait for a render, screenshot, record video, time keypress-to-paint, resize, switch theme and time zone, restart the server under the page, and run read-only queries, one command each. Use to prove any UI behavior in this repo, including the quick add bar's preview, add, undo, completion, category list, and calendar.
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

What it does, in order: builds Tailwind once if `app/assets/builds/tailwind.css` is missing, `bin/rails db:prepare`, `bin/rails db:seed` (creates `demo` or resets its password to the seeded one), starts `bin/rails server` detached on the port, waits for `/up` to return 200, starts headless Chrome, signs in through the real form. It does not use `bin/dev`: foreman exits without a TTY because the Tailwind watcher dies. `.claude/launch.json` still runs `bin/dev` for humans.

A fresh clone needs only `bin/setup --skip-server` first (installs gems, prepares the database). Then `boot` works with no other step.

Per-instance state lives in `tmp/verify/<port>/` (gitignored): `state.json`, `server.log`, `chrome.log`, `holder.log`, the Chrome profile.

## Doctor

```
$M doctor --port 3101
```

Prints JSON with `serverAlive`, `chromeAlive`, `holderAlive`, `up` (the `/up` status), the current `url`, `theme`, the recorded `viewport`, the live `inner` size, the emulated `timezone`, and the mp4 path being `recording`, if any. Exit 1 when the server or Chrome is down, `/up` is not 200, the viewport holder is dead, or `inner` differs from `viewport`. Run it first whenever a drive behaves oddly. A port that is busy with a process this skill did not start makes `boot` refuse with an error instead of attaching.

## Drive

| Action | Command |
| --- | --- |
| Type into a field | `$M type '[aria-label="Quick add"]' 'coffee 5.50' --port N` (add `--clear` to replace). Types key by key, so keydown handlers fire. Prints the field value. A second `type` appends at the caret, so type word by word and screenshot between words. `--delay 90` spaces the keys for a video. |
| Press keys | `$M key Enter --port N`. Also `Escape`, `Tab`, `ArrowDown`, `PageUp`, `Backspace`, a single character, `Meta+z`, `Ctrl+z`, `Shift+Tab`. Several keys in one call go back to back, under 1 ms apart: `$M key Enter Enter Enter` is a triple press, `$M key ArrowLeft ArrowLeft ArrowUp Tab` a sequence. |
| Wait for a render | `$M wait 'turbo-frame#draft' --text 'Type an amount' --port N` polls every 50 ms until an element matches the selector and contains the text, then prints its text. `--gone` waits until nothing matches. `--timeout 5000` is the default; a timeout exits 1. Wait before every `shot` that follows a server round trip, because `type` and `key` return before the response paints. |
| Click | `$M click 'button[data-theme="dark"]' --port N` |
| Screenshot | `$M shot /tmp/x/overview.png --port N` (`--full` for the whole page; it fires page resize events while it captures, so take full-page shots last when a lane watches resize events or popovers) |
| Resize viewport | `$M resize 375 812 --port N`. A small detached holder process per instance keeps the emulated viewport applied between commands, so the page does not see a resize until the next `resize`. Chrome headless cannot shrink its window below 500 px, which is why emulation is used. Prints `scrollWidth`; equal to the width means no horizontal scroll. |
| Switch theme | `$M theme dark --port N`. Real mouse click on the sidebar button, so the page must show the sidebar (`goto /` first). Waits for `html[data-theme]` and the `theme` cookie, and fails if the button is missing. |
| Navigate | `$M goto /session/new --port N` |
| Sign in or out | `$M signin demo wrong --port N`, `$M signout --port N` |
| Page text | `$M text '#alert' --port N` |
| Run JS | `$M js 'document.documentElement.dataset.theme' --port N` |
| Read-only query | `$M query 'Transaction.count'` |
| Restart the server under the page | `$M server stop --port N` kills only the Rails server; Chrome, the page, the field text, and focus stay. Requests now fail as they would on a dropped server. `$M server start --port N` starts it again and waits for `/up` without touching the page. |
| Browser time zone | `$M zone Pacific/Kiritimati --port N`, then `$M goto / --port N` so the page reads it on load. The holder keeps the override between commands. `$M zone off` returns to the host zone. `doctor` prints it. This changes what the browser reports, the real path, so prefer it over writing a cookie with `js`. |
| Video | `$M record start /tmp/x/review.mp4 --port N`, drive, `$M record stop --port N`. Prints the path, length, and frame count. A detached recorder screencasts the page at the viewport size, and `stop` encodes 30 fps H.264 with `ffmpeg` (must be on PATH). Frames arrive only when the page changes, and the encoder holds each one until the next, so wall time is kept. |
| Keypress-to-paint latency | `$M latency a --end turbo:frame-render --log /tmp/x/lat.jsonl --port N` presses the key and prints ms from its `keydown` timestamp to the first paint after the named event fires on the document (any bubbling event: `turbo:frame-render`, `turbo:morph`, `turbo:render`). `--end paint` measures to the next paint with no event, for client-only UI such as a menu or calendar. It first waits until the event has been quiet for 250 ms, so a late render from an earlier key is not counted. A sample with no event in 5 s logs `null` and exits 1. `$M latency --report /tmp/x/lat.jsonl` prints `{"n","timeouts","p50","p95","max"}`. |

Common handles: quick add input `[aria-label="Quick add"]`, preview frame `turbo-frame#draft`, popup `#quick-add-popup`, toast `[data-controller="toast"]` with Undo `[data-quick-add-target="undo"]`, theme buttons `button[data-theme="light"|"dark"]`, sign-in fields `#username` and `#password`, flash `#alert` and `#notice`. The full quick add bar list is in [features/quick-add-bar.md](features/quick-add-bar.md).

`query` evaluates the Ruby expression in `bin/rails runner` after reopening the database with SQLite `readonly: true`. `User.delete_all` and every other write fails with `SQLite3::ReadOnlyException`. The guard is the database connection, not a Ruby sandbox: `File.write` and `system` still run, so treat the expression as trusted input. It talks to the development database, so it needs no running instance.

The sign-in form is rate limited to 10 attempts per 3 minutes per client. A wrong-password drive costs one attempt.

## Evidence

- Screenshot every claim to a path you choose, for example `/tmp/<task>/owner/<slug>.png`, and look at the image. Evidence is the screenshot plus a number or string read back from the page (`type` prints the field value, `resize` prints `scrollWidth`, `theme` prints the attribute) plus `query` output for side effects.
- Drive the real path: `type` and `key` produce real key events, `click` real mouse events, sign-in uses the real form. Do not set values with `js` and call it typed.
- A key reaching the page is visible in the page, not in `log/development.log`, because key events are client side. Install a listener with `js` and read it back, or assert the visible result. Server requests an action triggers do show in `tmp/verify/<port>/server.log` and `log/development.log`.
- For a review video, `record start` before the first action and `record stop` after the last. Use `type --delay 90` so typing reads at human speed. Look at a frame or two (`ffmpeg -ss 2 -i x.mp4 -frames:v 1 f.png`) before posting it.
- For a perf budget, collect at least 20 samples with `latency --log`, report the `--report` line, and note the data size (`$M query 'Transaction.count'`). Timing is read from the page clock, so the cost of starting each `mp.mjs` process does not enter the number.
- The viewport holder accepts every `alert`, `confirm`, and `prompt` dialog at once and appends it to `tmp/verify/<port>/dialogs.log`, so a `data-turbo-confirm` button proceeds as if the user pressed OK. Read that log to prove a dialog appeared.
- The browser console is not exposed. Read errors from `server.log`, or `js` with `window.onerror` capture installed before the action.

## Cleanup

```
$M stop --port 3101
```

Stops that instance's viewport holder, Chrome and Rails server by recorded pid and deletes `tmp/verify/<port>/`. It never kills by name. A recording still running is finalized to its mp4 first. Screenshots, videos, and latency logs you saved outside `tmp/verify/` survive. The development database and the `demo` user stay.

## Two checkouts side by side

A regression lane compares trunk with a branch head. Run trunk from its own worktree, which has its own `storage/development.sqlite3` and `tmp/verify/`, on a different port:

```
git worktree add ../moneypouch-trunk origin/main
(cd ../moneypouch-trunk && bin/setup --skip-server && bin/rails "dev:transactions[100]")
../moneypouch-trunk/.claude/skills/verify-moneypouch/mp.mjs boot --port 3201
```

Drive each checkout with its own `mp.mjs`, since `mp.mjs` finds the app from its own location. A trunk older than a command (for example `wait` or `latency`) will not have it; use `js` and `shot` there. When done, `stop` the trunk port and `git worktree remove ../moneypouch-trunk`.

## Gotchas

- `bin/dev` and the plain `bin/rails server` both want `tmp/pids/server.pid`. `boot` uses `tmp/pids/verify-<port>.pid` so it can coexist with a human's `bin/dev` on 3000.
- Set `MP_CHROME` to a Chrome or Chromium binary when none is found in the default macOS and Linux locations.
- The Tailwind CSS is built once and not watched. After editing views with new utility classes, run `bin/rails tailwindcss:build` and reload with `goto`.
- Clicking a theme button submits a form and reloads the page, so the quick add field empties. Set the theme before typing.
- A hung or failed `boot`: read `tmp/verify/<port>/server.log` and `chrome.log`.

Feature map: [features/README.md](features/README.md).
