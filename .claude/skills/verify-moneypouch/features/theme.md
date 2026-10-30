# Theme

## Sub-features

- Mode: Light and Dark buttons in the Appearance section of the Settings page (`/settings`). Persists on `users.mode`, shown as `html[data-mode]`.
- Theme: a row of swatches (Pouch, Graphite, Moss, Tide, Ember, Rose, Plum). Persists on `users.theme`, shown as `html[data-theme]`. Each theme shifts the hue of the neutral ramp (Graphite drops the tint instead), and every theme but Pouch washes the light-mode page, so every theme works in both modes. The chosen swatch has `aria-pressed="true"`.

## How to get to it (user POV)

Sidebar, bottom left, the Settings link. Appearance has the Mode segmented control, then the Theme swatches. After a change the app redirects back to `/settings`.

## Driving it with mp.mjs

- `mp.mjs mode dark --port N` opens `/settings` when the button is not on the page, clicks it, and prints `dark`, the value of `html[data-mode]`.
- `mp.mjs theme moss --port N` does the same for a theme swatch. Screenshot with `shot`.
- Persistence check: `mp.mjs query 'User.find_by(username: "demo").slice(:mode, :theme)'`.
- Reset with `mp.mjs mode light --port N` and `mp.mjs theme pouch --port N`.

## Gotchas

- The mode and theme are stored on the shared `demo` user, so they carry across instances and runs. Reset to light and pouch when done.
