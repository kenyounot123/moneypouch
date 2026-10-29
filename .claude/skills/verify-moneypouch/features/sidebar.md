# Sidebar

## Sub-features

- Collapse to an icon rail and expand again with the panel button in the brand row. The state is `html[data-sidebar]`, `expanded` or `collapsed`, and persists in a `sidebar` cookie (`collapsed` when collapsed, anything else or no cookie means expanded). It is per device, with no database column.
- ⌘B (Ctrl+B) toggles it from anywhere on the page, including while typing in the palette. The toggle button names the shortcut in its `title` (`⌘B` on a Mac, `Ctrl B` elsewhere) and `aria-keyshortcuts`.
- Expanded the sidebar is 240px wide. Collapsed it is 64px: the pouch and wordmark hide, the toggle sits alone in the brand row, and nav links and Settings are 40x36 icon squares.
- Collapsed, each link's label becomes a tooltip to the right of the icon on hover and keyboard focus. The accessible name is the label in both states.
- `Add` sits between the brand row and the nav: a gold button with a plus icon and the `⌘K` chip (`Ctrl K` off a Mac, hidden on touch screens). The label is the one word so the wider `Ctrl K` chip still fits inside the 240px sidebar. It is `dialog-opener#open` for `dialog#palette`, which `_sidebar.html.erb` renders once on every page that has the sidebar. Collapsed it is a 40x36 gold plus square whose label is a tooltip like the links'. Below `md` it is hidden in the sheet, and the top bar shows a gold `Add` button at its right edge instead.
- `--container-sidebar` drops from 240px to 64px when collapsed, so the toast re-centers in the content area. The ⌘K palette is centered on the window and does not move.
- The server renders `data-sidebar` and the toggle's `aria-expanded` from the cookie, so the first paint has no flash.
- Below `md` the sidebar is a sheet. A top bar copies the brand row, and its button (`Show sidebar`) opens a modal `dialog[aria-label=Sidebar]`, 240px wide at the left edge, with the same links over a scrim. The page behind is inert and does not scroll. The open button sits at the left of the top bar, under the sheet, so only the sheet's `Hide sidebar` button shows. It closes on `Hide sidebar`, Escape, a tap on the scrim (the tap does not reach the page under it), any link (and stays closed on Back), a page morph, and a resize to `md` or wider. The collapsed cookie never shrinks the sheet.

## How to get to it (user POV)

Sidebar, top right of the brand row, desktop width (`md`, 768px) and up. Below `md`, the panel button at the top left of the page opens the sheet.

## Driving it with mp.mjs

- Toggle: `mp.mjs click 'button[aria-label="Toggle sidebar"]' --port N`. Read the state with `mp.mjs js 'document.documentElement.dataset.sidebar' --port N` and `aria-expanded` on the same button.
- Hotkey: `mp.mjs key Meta+b --port N` (or `Ctrl+b`), then read the state as above.
- Persistence: `mp.mjs goto / --port N` keeps the state. `mp.mjs js 'document.cookie' --port N` shows `sidebar=collapsed`.
- Tooltip: collapse, then `mp.mjs hover 'aside nav a[href="/transactions"]' --port N` and `shot`. The label shows to the right of the icon. A `click` would navigate, since Transactions is a real link.
- Geometry: `mp.mjs js 'document.querySelector("aside").getBoundingClientRect().right' --port N` prints 240 or 64. With the palette open (`key Meta+k`), `#palette` is centered on the window minus the scrollbar gutter, which stays reserved even while the open dialog hides the scrollbar: its rect's center reads 632.5 at 1280 wide, expanded or collapsed, and its top 176 (22vh of 800). `key Meta+b` toggles with the palette open; a `click` on the toggle lands on the scrim and closes the palette instead.
- Sheet: `mp.mjs resize 375 812 --port N`, `mp.mjs click 'button[aria-label="Show sidebar"]' --port N`, then `mp.mjs js 'document.querySelector("dialog[aria-label=Sidebar]").open' --port N` prints `true`. A scrim tap is a `click` on any page element right of x=240, for example `button[data-theme="dark"]` on Settings: the sheet closes and the theme stays. A `click` on `dialog[aria-label=Sidebar] nav` lands on the Categories `#` link and closes the sheet, so tap `dialog[aria-label=Sidebar] > div` to hit empty panel space.

## Gotchas

- The state is a cookie on the host, so it carries across ports and runs. Expand it again when done.
- A mouse click on the toggle after any key press shows a focus ring on it, because Chrome treats the page as keyboard driven. That is not a bug.
- Overview, Transactions, and Settings are real routes. Categories and Trends link to `#`, so clicking them changes the URL hash only. Import links to `/imports/new` and stays marked on every import step.
