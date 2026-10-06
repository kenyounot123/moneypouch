# Sidebar

## Sub-features

- Collapse to an icon rail and expand again with the panel button in the brand row. The state is `html[data-sidebar]`, `expanded` or `collapsed`, and persists in a `sidebar` cookie (`collapsed` when collapsed, anything else or no cookie means expanded). It is per device, with no database column.
- Expanded the sidebar is 240px wide. Collapsed it is 64px: the pouch and wordmark hide, the toggle sits alone in the brand row, and nav links and Settings are 40x36 icon squares.
- Collapsed, each link's label becomes a tooltip to the right of the icon on hover and keyboard focus. The accessible name is the label in both states.
- `--container-sidebar` drops from 240px to 64px when collapsed, so the ⌘K palette and the toast re-center in the content area.
- The server renders `data-sidebar` and the toggle's `aria-expanded` from the cookie, so the first paint has no flash.

## How to get to it (user POV)

Sidebar, top right of the brand row, desktop width (`md`, 768px) and up. Below `md` the sidebar is hidden.

## Driving it with mp.mjs

- Toggle: `mp.mjs click 'button[aria-label="Toggle sidebar"]' --port N`. Read the state with `mp.mjs js 'document.documentElement.dataset.sidebar' --port N` and `aria-expanded` on the same button.
- Persistence: `mp.mjs goto / --port N` keeps the state. `mp.mjs js 'document.cookie' --port N` shows `sidebar=collapsed`.
- Tooltip: `mp.mjs click 'aside nav a:nth-child(2)' --port N` leaves the mouse over the Transactions link (its href is `#`, so the page stays), then `shot`. There is no hover command.
- Geometry: `mp.mjs js 'document.querySelector("aside").getBoundingClientRect().right' --port N` prints 240 or 64. With the palette open (`key Meta+k`), `#palette` is centered on `(aside right + viewport width) / 2`.

## Gotchas

- The state is a cookie on the host, so it carries across ports and runs. Expand it again when done.
- A mouse click on the toggle after any key press shows a focus ring on it, because Chrome treats the page as keyboard driven. That is not a bug.
- Transactions, Categories, and Trends link to `#`, so clicking them changes the URL hash only.
