# Release notes

## Sub-features

- After an upgrade, the first signed-in page opens a modal `dialog[data-controller=release-notes]` (`shared/_release_notes`, rendered by the layout while `Current.user.unseen_releases.any?`). Unseen releases are the `CHANGELOG.md` versions above `users.seen_version` and not above `version.txt` (`Release`).
- It reads `You're now on version 0.20.0`, the release date, and the changelog's sections (`New`, `Fixed`, `Faster`) as bullets. Several unseen releases each get a version heading. `All releases` links to the GitHub releases page.
- `Got it` (`button[data-action="release-notes#close"]`) or a backdrop click closes it, and the close submits `POST /seen_release`, which saves the current version on `users.seen_version`. The next page has no dialog.
- A new account starts with `seen_version` at the current version, so it never sees the dialog. Settings, About shows the version.

## How to get to it (user POV)

Update the app, then open it.

## Driving it with mp.mjs

- Make it show: `bin/rails runner 'User.find_by!(username: "demo").update!(seen_version: "0.19.0")'` (any version below `version.txt`), then `mp.mjs goto / --port N` and `mp.mjs text 'dialog[open]' --port N`.
- Close it: `mp.mjs click 'dialog[open] button[data-action="release-notes#close"]' --port N`, `mp.mjs wait 'dialog[data-controller=release-notes][open]' --gone --port N`, then `mp.mjs query 'User.find_by(username: "demo").seen_version'` prints the current version.

## Gotchas

- While it is open it covers the page, so `click` on anything under it exits 1 with `covered by dialog[data-controller=release-notes]`. A pull that bumps `version.txt` makes it appear in the shared dev database on the next drive.
- `seen_version` lives on the shared `demo` user. Put back what `query` printed before the drive.
