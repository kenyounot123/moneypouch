# Theme

## Sub-features

- Light and Dark buttons in the Appearance section of the Settings page (`/settings`).
- The choice persists on the user (`users.background`) and in a `theme` cookie.

## How to get to it (user POV)

Sidebar, bottom left, the Settings link. Appearance has the Light and Dark segmented control. After a change the app redirects back to `/settings`.

## Driving it with mp.mjs

- `mp.mjs theme dark --port N` opens `/settings` when the button is not on the page, clicks it, and prints `dark`, the value of `html[data-theme]`. Screenshot with `shot`.
- Persistence check: `mp.mjs query 'User.find_by(username: "demo").background'` prints `"dark"`.
- Reset with `mp.mjs theme light --port N`.

## Gotchas

- The theme is stored on the shared `demo` user, so it carries across instances and runs. Reset to light when done.
