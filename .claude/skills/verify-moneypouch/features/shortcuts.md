# Keyboard shortcuts

## Sub-features

- `shortcuts_controller.js` sits on `<body>` of every signed-in page (`body[data-controller=shortcuts][data-action="keydown@window->shortcuts#press"]`). It owns the plain keys in its `KEYMAP`: `/` is `search`, `ArrowLeft` is `previousMonth`, `ArrowRight` is `nextMonth`. Shortcuts with a modifier stay with their owners: ⌘K and ⌘Z in `palette_controller.js`, ⌘B in `sidebar_controller.js`.
- A key does nothing while Meta, Ctrl, or Alt is held, during IME composition, on a repeat, when another handler already prevented it, when the target is in an `input`, `textarea`, `select`, or `[contenteditable]`, or while any `dialog[open]` exists (the ⌘K palette, the edit sheet, the phone sidebar). The arrows also do nothing with Shift. `/` allows Shift, because some layouts need it.
- `/`: on the ledger it focuses `[aria-label="Search transactions"]` and prevents the default, so Firefox's Quick Find does not open. On any other signed-in page it visits `data-shortcuts-transactions-url-value` (`/transactions`), and the field takes focus once the ledger renders.
- Arrows: click the first visible `[data-shortcuts-target=previousMonth]` or `[data-shortcuts-target=nextMonth]`, the phone or desktop copy of the month step. See [transactions.md](transactions.md).
- The categorize chain needs no new key. See [transactions.md](transactions.md).
- Settings, Keyboard section: `Single-key shortcuts` with an `On`/`Off` pair of `button_to` forms to `PATCH /shortcuts` (`on=true|false`, `ShortcutsController`, `User#use_single_key_shortcuts`). The saved choice is `button[aria-pressed=true]`. The column is `users.single_key_shortcuts`, default true. It is the WCAG 2.1.4 switch for character-key shortcuts, so it gates `/` only, never the arrows.
- Off: `body[data-shortcuts-single-key-value=false]`, `/` does nothing anywhere, and the search field has no `aria-keyshortcuts` and no `/` chip.

## How to get to it (user POV)

Press `/` on any page, or the arrow keys on the Transactions page. The switch is in Settings under Keyboard.

## Driving it with mp.mjs

- `/` from elsewhere: `$M goto /`, `$M key /`, then read `[location.pathname, document.activeElement.getAttribute("aria-label")]`, expecting `/transactions` and `Search transactions`.
- `/` stays text in a field: `$M key Meta+k`, `$M type '[aria-label="Add"]' 'tea /'`, and the value keeps the slash with the palette still open. On the ledger a second `$M key /` after the first types `/` into the search field.
- Arrows: `$M goto '/transactions?month=2026-09'`, `$M key ArrowLeft`, then `location.search` reads `?month=2026-08`.
- Switch: `$M goto /settings`, `$M click 'form[action="/shortcuts"] button:not([aria-pressed=true])'`, `$M wait 'form[action="/shortcuts"] button[aria-pressed=true]' --text Off`.

## Gotchas

- `mp.mjs key` sends no repeat, so holding an arrow is not covered by a drive. A held arrow is ignored by design.
- Headless Chrome reports a fine pointer, so the `/` chip shows in a drive at widths where a phone would hide it with `pointer-coarse:hidden`.
