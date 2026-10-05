# Overview

## Sub-features

- Quick add bar at the top, an input labelled "Quick add", with the preview frame `turbo-frame#draft` under it. See [quick-add-bar.md](quick-add-bar.md).
- Spent total, category breakdown, daily bars, recent transactions.
- Sidebar with navigation and the theme switch.

## How to get to it (user POV)

Sign in. `/` is the Overview.

## Driving it with mp.mjs

- `mp.mjs type '[aria-label="Quick add"]' hello --port N` prints `"hello"`, the field value.
- `mp.mjs key Enter --port N` presses Enter in the focused field.
- `mp.mjs shot <path>.png --port N`, then read the image.
- `mp.mjs resize 375 812 --port N` prints `scrollWidth=375` when the page has no horizontal scroll.
- `mp.mjs query 'Transaction.count'` reads the stored count.

## Gotchas

- The Overview figures are static markup today and do not follow the database.
- Typing in the quick add field renders the preview through `GET /draft`. Wait on the frame text before a `shot`.
