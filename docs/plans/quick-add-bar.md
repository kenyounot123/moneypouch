# Quick add bar plan

The quick add bar on the Overview becomes the place where a person types one line per purchase and sees exactly what will be saved before pressing Enter.
A preview row shows the row that will land in Recent, and a legend under it names what the line can hold and checks each part the line already uses.
Three typing aids keep hands on the keyboard. `#` opens the categories with the usual one first, `@` opens a calendar driven by arrow keys, and Tab finishes a name used before.
The rule the program enforces is that `Transaction::Draft` alone decides what a line means. The client only edits text and never parses it.
The PR ids in order are Q1 to Q5. The prototype that chose this design is [prototypes/quick-add-bar.html](prototypes/quick-add-bar.html), variant **C3 · Assist**.

## How to read this

One box is one unit of work. Every box names the evidence that checks it. A nested box is a sub-step of the box above it. Check a box only when its evidence exists, a file, a log line, a screenshot, a test run, or a SHA. The body is a how-to. The appendices explain and record.

The program runs `kstack/skills/k-mode/playbooks/autopilot-stack.md` (on this machine `/Users/kenlu/kstack/skills-src/k-mode/playbooks/autopilot-stack.md`). No agent merges. The root appends each verified PR to one linear stack on `main` and the operator lands it bottom-up. The operator may take any PR as its owner and write the code personally. The root then only verifies and appends.

Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

## Program checklist

### Arm the program

- [ ] State the protocol and this plan to the operator, then stop. Start execution only on their explicit go.
- [ ] On their go, arm a `/goal` with this exact text. "Run docs/plans/quick-add-bar.md under autopilot-stack. Build Q1 to Q5 in order as one linear stack on main. A PR is verified only when its unit, live, and perf boxes are all checked. No agent merges. The operator reviews and lands every PR. Done when Q1 to Q5 each carry a clean swarm verdict at their head SHA and sit in the stack."
- [ ] Read these at program start. Re-read them at every tick.
  - [ ] `cat /Users/kenlu/kstack/skills-src/k-mode/playbooks/autopilot-stack.md`
  - [ ] `cat /Users/kenlu/kstack/skills-src/swarm/SKILL.md`
  - [ ] `git show origin/main:.claude/skills/verify-moneypouch/SKILL.md`
  - [ ] `git show origin/main:.claude/skills/verify-moneypouch/features/add-transaction.md`
  - [ ] `git show origin/main:.claude/skills/verify-moneypouch/features/draft.md`
  - [ ] `cat /Users/kenlu/kstack/skills-src/k-mode/playbooks/opening-a-pr.md`
  - [ ] `cat /Users/kenlu/kstack/skills-src/rails-best-practices/SKILL.md`
- [ ] Arm the 30-minute audit tick. In a local session, a real terminal `/loop`. In a cloud root, a cloud-sleeper wake chain. Never leave the cadence to memory.
- [ ] Use this tick prompt, verbatim. "Re-read the execution playbook from trunk and the armed /goal. Audit the operation against both and fix drift in this tick. Probe every active lane and judge progress by side effects only. Stand down a stuck lane and dispatch its replacement now. Then send the operator a status message, whether or not anything changed, with the queue table of PR, owner, state, and head SHA, the verdicts since the last tick, what merged, open operator gates, and blockers."
- [ ] On the operator's hold or stand-down, send every owner a zero-writes order at once.

### Spawn owners

- [ ] Spawn one owner per PR with the full lifecycle the execution playbook names.
- [ ] Follow this dependency graph. Base each branch on its parent branch, since the program stacks.
  - [ ] Q1 is first. It branches from `main`.
  - [ ] Q2 after Q1. Q3 after Q2. Q4 after Q3.
  - [ ] Q5 depends only on Q2. It may build in parallel with Q3 and Q4 and appends last.
- [ ] Hold the file boundaries.
  - [ ] Q1 to Q5 touch only `app/`, `config/routes.rb`, `test/`, and `.claude/skills/verify-moneypouch/`.
  - [ ] Only Q1 edits `app/models/transaction/draft.rb`. Only Q2 edits `app/controllers/transactions_controller.rb`.
  - [ ] Q5 touches no Ruby outside `test/`.
- [ ] Hold the review gate. Q1 to Q5 all change an interaction. Each waits for the operator's review in chat with screenshots and a video before merge.

### PR mechanics, for every PR

- [ ] Resolve the forge once. Default to `gh`; if `command -v origin` succeeds and Origin can resolve the repository, use `origin pr` for every PR operation. Record any fallback to `gh`. Never require `gt`.
- [ ] Open the PR ready, never draft, with `origin pr create --status open --base <base-branch>` or `gh pr create --base <base-branch>` according to the resolved forge. A stack child targets its parent branch.
- [ ] Run `bin/ci` once before the PR-facing push. It runs rubocop, bundler-audit, importmap audit, brakeman, the Rails tests, and the seed replant. Push with hooks on.
- [ ] Run `/no-comments` and `principle-laziness-protocol` over the diff before each commit, and `/no-comments` before review.
- [ ] Triage every Bugbot and security-reviewer comment per `/Users/kenlu/kstack/skills-src/k-mode/references/bugbot-triage.md`.
- [ ] Update the matching file under `.claude/skills/verify-moneypouch/features/` in the same PR, so the next lane can drive the new behavior.
- [ ] Rebase onto current trunk before babysit and again before the merge-ready report.

### Verdict and merge, for every PR

- [ ] At the merge-ready head SHA, run the swarm per `/Users/kenlu/kstack/skills-src/swarm/SKILL.md`. One gates lane. The ten live lanes from the PR's **Verify, live** block. The perf lane from its **Verify, perf** block. One audit lane that reads the diff and the receipts and distrusts the PR body.
- [ ] Clean only when every lane is `PASS`. Findings go back to the owner. A new head gets a fresh swarm and a fresh verdict.
- [ ] Append on a clean verdict. Rebase the child onto its parent's exact tip and compare `git patch-id` against the verdict SHA. An unchanged patch-id keeps the verdict. A changed one goes back through the swarm. The operator lands the stack bottom-up.

### Boot recipe, for every live lane

Each live lane runs in its own remote subagent at the PR head. Drive through the repo's `verify-moneypouch` skill with `M=.claude/skills/verify-moneypouch/mp.mjs`.

- [ ] `git fetch origin <head-branch> && git checkout <head SHA>`.
- [ ] Run `bin/setup --skip-server`, then `bin/rails "dev:transactions[100]"` so names and categories have history. Run `$M boot --port <free port>` and wait for the printed URL.
- [ ] Deliver every keypress and click through `$M type`, `$M key`, and `$M click`. Read-only diagnostics are `$M query`, `$M text`, `$M js`, and `tmp/verify/<port>/server.log`.
- [ ] Save every screenshot to `/tmp/swarm-<pr-id>/worker-<n>/<slug>.png` and return the paths with the report.

## Preview a typed line under the bar (Q1)

**Depends on.** None.

**Files.**

- [ ] Edit `app/models/transaction/draft.rb` and `test/models/transaction/draft_test.rb`.
- [ ] Create `app/controllers/drafts_controller.rb`, `app/views/drafts/show.html.erb`, and `app/views/drafts/_draft.html.erb`.
- [ ] Create `app/views/shared/_quick_add.html.erb` from the bar markup in `app/views/welcome/index.html.erb`.
- [ ] Create `app/javascript/controllers/quick_add_controller.js` and `app/javascript/controllers/time_zone_controller.js`.
- [ ] Edit `app/views/welcome/index.html.erb`, `app/views/layouts/application.html.erb`, `app/controllers/application_controller.rb`, and `config/routes.rb`.
- [ ] Create `test/controllers/drafts_controller_test.rb`.

**Build.**

- [ ] Change `Transaction::Draft::MISSING_AMOUNT` to `Type an amount, like 5.50` and `MISSING_NAME` to `Type a name, like coffee`. Update the literal expectations in `draft_test.rb`.
- [ ] Add `dated` to `Transaction::Draft::Reading` and delegate `Draft#dated?`. It is true only when the line names a date, so `coffee 5` is not dated and `coffee 5 today` is.
- [ ] Set a `time_zone` cookie from the browser in `time_zone_controller.js`, copying the cookie pattern in `background_controller.js`. Wrap each request in `Time.use_zone` from that cookie in `ApplicationController`, falling back to UTC for an unknown zone, so `Date.current` is the user's today.
- [ ] Add `resource :draft, only: :show`. `DraftsController#show` parses `params[:line]` plus `params[:completion]` with `Transaction::Draft.parse(line, user: Current.user, today: Date.current)` and renders `<turbo-frame id="draft">`.
- [ ] Render `drafts/_draft.html.erb` with two parts, matching the prototype's C3 markup.
  - [ ] The preview row, shaped like a Recent row. Name, category with `(usual)` when `inferred?` or `(new)` when the category is unsaved, the date as Today, Yesterday, or `Sep 24`, and the amount. A missing name or amount shows its error as a red outlined callout with a warning icon in the spot where that value goes. The row carries `data-inferred-category` when `inferred?`.
  - [ ] The legend. `5.50` amount, `@` date, `#` category, and `+20` money in. A part the line uses gets the highlight chip and a check. The amount part turns red while the line is not empty and has no amount. An empty line shows only the legend.
- [ ] Make `quick_add_controller.js` set the frame's `src` to `/draft?line=` on each `input` event. Turbo cancels the stale request, so only the latest line paints. Expose a `quick-add:preview` event whose `detail` carries a `line` and an optional `completion`, so Q3 to Q5 can preview a pending change without owning the frame.
- [ ] Remove the static `$5.50`, `Food`, and `Sep 26` pills from the bar.
- [ ] Let the amount callout wrap below the name at phone width, as the prototype's `flex-wrap` and `basis-44` row does.

**You see.**

- [ ] Typing `Spotify yesterday` shows a preview row `Spotify`, `Subscriptions (usual) · Yesterday`, and the callout `Type an amount, like 5.50`. The legend shows `@` date with a check and `5.50` amount in red.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `draft_test.rb` gains literal cases that `coffee 5` reads `dated: false` and `coffee 5 yesterday`, `coffee 5 sep 24`, and `coffee 5 9/24` read `dated: true`. Run `bin/rails test test/models/transaction/draft_test.rb`.
- [ ] `drafts_controller_test.rb` gains a case that `GET /draft?line=coffee` contains `Type an amount, like 5.50`, and a case that another user's categories never appear. Run `bin/rails test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Type `Spotify yesterday` at trunk and head. Trunk shows static pills and no preview, so record that and gate the head result. Save `preview.png`. Pass when the head shows the preview row and legend from **You see**.
- [ ] Lane 2. Type `Trader Joe's 64.12 sep 18 #Shopping` one character at a time with `$M type` and screenshot after each word. Save `preview-steps.png`. Pass when the row always matches the text typed so far.
- [ ] Lane 3. Type `5.50` only. Save `missing-name.png`. Pass when the name spot shows `Type a name, like coffee` as a red callout.
- [ ] Lane 4. Type `lunch 12 #brandnew`. Save `new-category.png`. Pass when the row shows `brandnew (new)` and `$M query 'Category.count'` is unchanged.
- [ ] Lane 5. Type `paycheck +2400`. Save `money-in.png`. Pass when the amount shows `+$2,400.00` in the success color and the legend checks money in.
- [ ] Lane 6. Clear the field. Save `empty.png`. Pass when only the legend shows and no row or callout remains.
- [ ] Lane 7. Set the `time_zone` cookie to `Pacific/Kiritimati` with `$M js`, reload with `$M goto /`, and type `tea 3 today`. Save `zone.png`. Pass when the row date equals today in that zone, as `$M query 'Time.use_zone("Pacific/Kiritimati") { Date.current }'` prints.
- [ ] Lane 8. Type `Spotify yesterday` at 375 by 812. Save `phone.png`. Pass when the callout wraps below the name, `$M resize` prints `scrollWidth=375`, and nothing overlaps.
- [ ] Lane 9. Type `Spotify yesterday` in dark mode. Save `dark.png`. Pass when the row, callout, and legend use the dark tokens and the callout stays readable.
- [ ] Lane 10. Type 20 characters fast, then stop. Save `latest-wins.png`. Pass when the final row matches the final text and no earlier row paints after it.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Milliseconds from keypress to the updated preview row painted, with 10000 transactions for `demo`. Trunk has no preview, so this is an absolute budget.
- [ ] Probe. Run `bin/rails "dev:transactions[10000]"`, then drive 50 keypresses with `$M type` and read `performance.now()` marks set on `input` and on `turbo:frame-render` through `$M js`.
- [ ] Baseline. Record that trunk has no preview and say so in the report.
- [ ] Rule. Fail when the p95 exceeds 100 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1, 3, and 8 screenshots into `docs/plans/media/Q1-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of typing three lines, one of them missing an amount. Save it as `docs/plans/media/Q1-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends Q1 to the stack and the operator lands it bottom-up.

## Add the line on Enter with undo (Q2)

**Depends on.** Q1.

**Files.**

- [ ] Edit `app/controllers/transactions_controller.rb`, `app/views/shared/_quick_add.html.erb`, `app/javascript/controllers/quick_add_controller.js`, `app/views/welcome/index.html.erb`, `app/views/layouts/application.html.erb`, and `app/models/transaction.rb`.
- [ ] Create `app/views/transactions/_transaction.html.erb` from the Recent row markup in `app/views/welcome/index.html.erb`, replacing the empty partial.
- [ ] Create `app/views/shared/_toast.html.erb`.
- [ ] Edit `test/controllers/transactions_controller_test.rb`.

**Build.**

- [ ] Spike first. Confirm that a Turbo 8 morph refresh after a same-page redirect keeps focus in the bar and sets the field value the server renders. Record the result in the PR. If it fails, mark the bar `data-turbo-permanent` and let the controller clear or refill it.
- [ ] Make the bar a `form_with url: transactions_path` with a `line` field and a hidden `idempotency_key` set to `SecureRandom.uuid` on each render. A failed request leaves the form in place, so a retry sends the same key. A successful add re-renders the form with a new key.
- [ ] Make Enter and **Add ↵** submit only when no popup is open. A popup sets `aria-expanded="true"` on the field, and Q3 to Q5 rely on this check.
- [ ] Make `TransactionsController#create` parse `params[:line]` with `Transaction::Draft.parse`, then create the row from `Draft#attributes` plus the key. A repeated key returns the existing row. An invalid line responds 422 with the draft frame and keeps the text.
- [ ] Redirect back with `303 See Other` and `turbo_refreshes_with method: :morph, scroll: :preserve`, so the field clears and Recent updates in one render.
- [ ] Render Recent from the 5 latest kept transactions, ordered by `occurred_on` then `id` descending, with `transactions/_transaction.html.erb`. The rest of the Overview stays static in this program.
- [ ] Render `shared/_toast.html.erb` after an add. It reads `Added <name> <amount>` and holds an **Undo** button with the key hint `⌘Z` on macOS and `Ctrl Z` elsewhere. The toast fades after 5 seconds.
- [ ] Change `TransactionsController#destroy` to call `Transaction#discard` instead of `destroy!`. **Undo** sends `DELETE /transactions/:id` and redirects back with the discarded row's `line` in the field.
- [ ] Bind `⌘Z` and `Ctrl+Z` in the empty field to the toast's **Undo** while the toast shows.

**You see.**

- [ ] Typing `coffee 5.50 yesterday` and pressing Enter adds `coffee` to Recent, empties the field, and shows `Added coffee $5.50` with **Undo**. Pressing `⌘Z` removes the row and puts `coffee 5.50 yesterday` back in the field.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `transactions_controller_test.rb` gains a case that posting `line=coffee 5.50` creates one transaction with `amount_in_cents` `-550` and `line` `coffee 5.50`. Run `bin/rails test`.
- [ ] It gains a case that two posts with the same `idempotency_key` create one row.
- [ ] It gains a case that `DELETE` sets `discarded_at` and leaves `Transaction.count` unchanged, replacing the hard-delete test.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Type `coffee 5.50 yesterday` and press Enter at trunk and head. Trunk saves nothing, as `features/add-transaction.md` records, so record that and gate the head result. Save `add.png`. Pass when the head shows the new row in Recent, the toast, an empty field, and one new row from `$M query`.
- [ ] Lane 2. Type `coffee` and press Enter. Save `blocked.png`. Pass when the callout shakes, the text stays, and the count is unchanged.
- [ ] Lane 3. Press Enter three times fast on a valid line. Save `triple-enter.png`. Pass when exactly one row is created.
- [ ] Lane 4. Add a line, then press `⌘Z` in the empty field. Save `undo.png`. Pass when the row leaves Recent, `discarded_at` is set in `$M query`, and the field holds the original line.
- [ ] Lane 5. Add a line, wait 6 seconds, press `⌘Z`. Save `undo-expired.png`. Pass when nothing changes.
- [ ] Lane 6. Add `Trader Joe's 42.18 sep 18`. Save `backdated.png`. Pass when the toast names the row even though Recent may not show it at the top.
- [ ] Lane 7. Add `lunch 12 #brandnew`. Save `new-category-saved.png`. Pass when category `brandnew` exists once and the row shows it.
- [ ] Lane 8. Stop the server, press Enter, start the server, press Enter again. Save `retry.png`. Pass when the field keeps its text after the failure and the retry creates exactly one row.
- [ ] Lane 9. Add a line at 375 by 812. Save `phone.png`. Pass when the toast and the new row fit with `scrollWidth=375`.
- [ ] Lane 10. Add and undo in dark mode. Save `dark.png`. Pass when the toast and Recent use the dark tokens.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Milliseconds from Enter to the new row painted in Recent, and from `⌘Z` to the row removed, with 10000 transactions. Trunk has no save, so these are absolute budgets.
- [ ] Probe. Drive 20 adds and 20 undos with `$M key` and read `performance.now()` marks on `keydown` and on `turbo:morph` through `$M js`.
- [ ] Baseline. Record that trunk has no save or undo and say so in the report.
- [ ] Rule. Fail when either p95 exceeds 300 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1, 4, and 6 screenshots into `docs/plans/media/Q2-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of adding three lines and undoing one. Save it as `docs/plans/media/Q2-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends Q2 to the stack and the operator lands it bottom-up.

## Finish a used name with Tab (Q3)

**Depends on.** Q2.

**Files.**

- [ ] Create `app/controllers/completions_controller.rb` and `app/javascript/controllers/completion_controller.js`.
- [ ] Edit `app/views/shared/_quick_add.html.erb`, `app/views/drafts/_draft.html.erb`, `app/controllers/drafts_controller.rb`, and `config/routes.rb`.
- [ ] Create `test/controllers/completions_controller_test.rb`.

**Build.**

- [ ] Add `resources :completions, only: :index`. `CompletionsController#index` returns JSON with the user's distinct kept names, each with its latest category, ranked by use count then latest `occurred_on`, plus the user's category names.
- [ ] Fetch the list in `completion_controller.js` when the bar gains focus and again on `turbo:morph` after each add.
- [ ] Offer a name only while the caret is at the end, the line has at least 2 characters, and the line holds no digit, `#`, `@`, `$`, or `+`. Match by case-insensitive prefix and offer the first ranked hit.
- [ ] Send the remainder as `completion` through `quick-add:preview`. `drafts/_draft.html.erb` renders the typed part in full color, the remainder dimmed, and a `Tab` key chip. The category comes from the completed name, so `Tra` shows `Food (usual)`.
- [ ] Make Tab replace the line with the full name plus a space. Tab with no offer keeps its normal focus move.

**You see.**

- [ ] Typing `Tra` shows `Trader Joe's` with `der Joe's` dimmed, a `Tab` chip, and `Food (usual) · Today`. Tab turns the line into `Trader Joe's `.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `completions_controller_test.rb` gains a case that a discarded transaction's name and another user's names are absent, and that the latest category wins for a repeated name. Run `bin/rails test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Type `Tra` and press Tab at trunk and head. Trunk moves focus away, so record that and gate the head result. Save `tab.png`. Pass when the head line reads `Trader Joe's ` and focus stays in the bar.
- [ ] Lane 2. Type `Tra` and screenshot before Tab. Save `offer.png`. Pass when the row shows the dimmed remainder, the `Tab` chip, and the usual category.
- [ ] Lane 3. Type `Tra 6`. Save `no-offer-digit.png`. Pass when no remainder shows.
- [ ] Lane 4. Type `T`. Save `too-short.png`. Pass when no remainder shows.
- [ ] Lane 5. Move the caret into the middle of `Trad` with `$M key ArrowLeft`. Save `mid-caret.png`. Pass when no remainder shows and Tab moves focus.
- [ ] Lane 6. Add `Zebra Cafe 4`, then type `Zeb`. Save `fresh.png`. Pass when `Zebra Cafe` is offered without a reload.
- [ ] Lane 7. Discard a row named `Lyft` through `/transactions` while keeping no other `Lyft` row, then type `Ly`. Save `discarded.png`. Pass when `Lyft` is not offered.
- [ ] Lane 8. Type a prefix with no match and press Tab. Save `no-match.png`. Pass when focus moves to **Add ↵** and the line is unchanged.
- [ ] Lane 9. Use Tab completion at 375 by 812. Save `phone.png`. Pass when the row truncates the name without horizontal scroll.
- [ ] Lane 10. Use Tab completion in dark mode. Save `dark.png`. Pass when the dimmed remainder and chip stay readable.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Server time for `GET /completions` with 2000 distinct names, and milliseconds from keypress to the dimmed remainder painted. Trunk has neither, so these are absolute budgets.
- [ ] Probe. Time `GET /completions` five times warm from `server.log`, and drive 50 keypresses with `performance.now()` marks through `$M js`.
- [ ] Baseline. Record that trunk has no completion and say so in the report.
- [ ] Rule. Fail when the endpoint median exceeds 100 milliseconds or the keypress p95 exceeds 100 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1, 2, and 9 screenshots into `docs/plans/media/Q3-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of finishing two names with Tab and adding them. Save it as `docs/plans/media/Q3-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends Q3 to the stack and the operator lands it bottom-up.

## Pick a category after # (Q4)

**Depends on.** Q3.

**Files.**

- [ ] Edit `app/javascript/controllers/completion_controller.js` and `app/views/shared/_quick_add.html.erb`.

**Build.**

- [ ] Open a listbox under the bar when the word at the caret starts with `#`. Set `role="combobox"`, `aria-expanded`, and `aria-controls` on the field and `role="option"` with `aria-selected` on each item.
- [ ] Filter the user's categories by case-insensitive prefix of the text after `#`. Put the category from the preview row's `data-inferred-category` first and tag it `usual`.
- [ ] When the typed word matches no category, end the list with `New category <word>`.
- [ ] Make Up and Down move the selection, Tab or Enter replace the word with `#<Category> `, a click do the same, and Esc close the list and keep the text.
- [ ] Place the list under the word at the caret, clamped inside the bar's width, as the prototype's `place` function does.

**You see.**

- [ ] On `Trader Joe's 64.12 #`, the list opens with `Food usual` selected and a `Tab` chip. Tab turns the line into `Trader Joe's 64.12 #Food `, and the legend checks category.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `drafts_controller_test.rb` gains a case that the preview row for `Trader Joe's 64.12 #` carries `data-inferred-category="Food"` when the user's latest `Trader Joe's` row is in Food. Run `bin/rails test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Type `Trader Joe's 64.12 #` at trunk and head. Trunk has no list, so record that and gate the head result. Save `menu.png`. Pass when the head list opens with the usual category first.
- [ ] Lane 2. Type `#sh` and press Tab. Save `filter.png`. Pass when the word becomes `#Shopping ` and the rest of the line is unchanged.
- [ ] Lane 3. Type `#`, press Down twice, press Enter. Save `arrows.png`. Pass when the third item is picked and nothing is added.
- [ ] Lane 4. Type `#brandnew` and press Tab. Save `new.png`. Pass when the list showed `New category brandnew` and the row shows `brandnew (new)`.
- [ ] Lane 5. Type `#fo` and press Esc. Save `esc.png`. Pass when the list closes, the text stays, and the next Enter adds the line.
- [ ] Lane 6. Put the caret inside `#fo` in the middle of a line and press Tab. Save `mid-line.png`. Pass when only that word is replaced.
- [ ] Lane 7. Click an item. Save `click.png`. Pass when the word is replaced and focus stays in the field.
- [ ] Lane 8. Read the field's ARIA with `$M js` while the list is open. Save `aria.png`. Pass when `aria-expanded` is `true` and exactly one option has `aria-selected="true"`.
- [ ] Lane 9. Open the list at the end of a long line at 375 by 812. Save `phone.png`. Pass when the list stays inside the viewport and `scrollWidth=375`.
- [ ] Lane 10. Open the list in dark mode. Save `dark.png`. Pass when the list and its selected item use the dark tokens.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Milliseconds from the `#` keypress, or an arrow keypress, to the list painted, with 200 categories. Trunk has no list, so this is an absolute budget.
- [ ] Probe. Seed 200 categories for `demo` with a `bin/rails runner` one-liner kept out of the diff, then drive 50 keypresses with `performance.now()` marks through `$M js`.
- [ ] Baseline. Record that trunk has no list and say so in the report.
- [ ] Rule. Fail when the p95 exceeds 16 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1, 4, and 9 screenshots into `docs/plans/media/Q4-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of picking the usual category, filtering to another, and making a new one. Save it as `docs/plans/media/Q4-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends Q4 to the stack and the operator lands it bottom-up.

## Pick a date after @ (Q5)

**Depends on.** Q2, which adds the `aria-expanded` check on Enter. Q5 appends after Q4.

**Files.**

- [ ] Create `app/javascript/controllers/calendar_controller.js`.
- [ ] Edit `app/views/shared/_quick_add.html.erb` and `test/models/transaction/draft_test.rb`.

**Build.**

- [ ] Open a calendar under the bar when the word at the caret is exactly `@`. Start on the date the line already names, else today. Set `aria-expanded` on the field and `role="grid"` on the month.
- [ ] Make Left and Right move a day, Up and Down a week, and PageUp and PageDown a month. Show the month name with previous and next buttons.
- [ ] Make Tab, Enter, or a click replace the `@` with a date word the grammar reads. Use `today`, `yesterday`, `sep 24` for this year, and `sep 24 2025` for another year. Make `t` pick today and `y` pick yesterday.
- [ ] Make Esc close the calendar and remove the `@`. Make any other printable key remove the `@`, close the calendar, and type the key.
- [ ] Grey out future days and stop the cursor at today. This is the operator's open decision in Appendix C, so build it behind one `max` value.
- [ ] Send the line with the cursor's date word in place of `@` through `quick-add:preview`, so the row shows the date before the pick.
- [ ] Show the footer hints in two columns, `←↑↓→ move`, `Tab pick`, `t today`, and `y yesterday`.

**You see.**

- [ ] On `Lyft 9 @`, the calendar opens on today. PageUp then Tab turns the line into `Lyft 9 aug 27 ` and the row shows `Transport (usual) · Aug 27`.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `draft_test.rb` gains a literal case per date word the calendar writes, `today`, `yesterday`, `aug 27`, and `dec 31 2025`, each with a fixed `today:` and its expected `occurred_on`. Run `bin/rails test test/models/transaction/draft_test.rb`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Type `Lyft 9 @` at trunk and head. Trunk has no calendar, so record that and gate the head result. Save `calendar.png`. Pass when the head calendar opens on today with today selected.
- [ ] Lane 2. Press Left twice, Up once, then Tab. Save `arrows.png`. Pass when the line holds the date 9 days back as a grammar word and the row shows it.
- [ ] Lane 3. Press PageUp then Tab. Save `month.png`. Pass when the line holds the same day last month.
- [ ] Lane 4. Press `y`. Save `yesterday.png`. Pass when the line reads `Lyft 9 yesterday `.
- [ ] Lane 5. Press Esc. Save `esc.png`. Pass when the calendar closes and the `@` is gone.
- [ ] Lane 6. Press Right on today. Save `future.png`. Pass when the cursor stays on today and future days are greyed.
- [ ] Lane 7. Pick a date in the previous year with PageUp, then add the line. Save `last-year.png`. Pass when the saved `occurred_on` from `$M query` matches the picked date.
- [ ] Lane 8. Press Enter with the calendar open. Save `enter-picks.png`. Pass when the date is picked and no row is added.
- [ ] Lane 9. Open the calendar at 375 by 812. Save `phone.png`. Pass when it fits inside the viewport and `scrollWidth=375`.
- [ ] Lane 10. Open the calendar in dark mode. Save `dark.png`. Pass when the grid, selected day, and today mark use the dark tokens.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Milliseconds from an arrow keypress to the calendar cursor painted. Trunk has no calendar, so this is an absolute budget.
- [ ] Probe. Drive 50 arrow keypresses with `performance.now()` marks through `$M js`.
- [ ] Baseline. Record that trunk has no calendar and say so in the report.
- [ ] Rule. Fail when the p95 exceeds 16 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1, 2, and 9 screenshots into `docs/plans/media/Q5-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of typing a whole line with `#`, `@`, and Tab and no mouse. Save it as `docs/plans/media/Q5-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends Q5 to the stack and the operator lands it bottom-up.

## Close the program

- [ ] Every box above is checked with its evidence.
- [ ] Reply to the operator with the report the execution playbook names.

## Appendix A. Prototype evidence

The prototype is [prototypes/quick-add-bar.html](prototypes/quick-add-bar.html). It keeps variants C1 and C3 behind a switcher. Open it from the repo so the fonts under `app/assets/fonts/` load. Its parser is a stand-in for `Transaction::Draft::Grammar`, so do not build from its code.

It settled these questions in a browser, driven with real key events.

- A preview row beats pills and in-field highlighting. Pills hide below 640 pixels, and the highlight overlay drifted from the caret once and could not show a misread.
- A legend beats hints inside the row. Hints inside the row vanished once a category was inferred, which is when a person wants to override it.
- The missing-amount callout reads at a glance in light and dark, and at phone width it wraps below the name. See `media/prototype-missing-amount.jpg` and `media/prototype-missing-amount-phone.jpg`.
- `#` with the usual category first makes the common case two keys. See `media/prototype-category-menu.jpg`.
- `@` with arrow keys, PageUp, `t`, and `y` picks any past date without the mouse, and the picked words parse. See `media/prototype-calendar.jpg`.
- A whole line, `Trader Joe's 64.12 #Shopping sep 18`, takes about 20 keys with every legend part checked. See `media/prototype-full-line.jpg`.

These stay unproven until the owners measure them.

- The 100 millisecond preview budget with a server round trip per keypress (Q1).
- Whether a morph refresh keeps focus in the bar (Q2 spike).

## Appendix B. Alternatives rejected

- **A client-side copy of the parser.** It would paint faster, but two parsers drift. The preview row depends on inference from history, which only the server has. It stays the fallback if the Q1 perf gate fails.
- **A read-back sentence**, as the closed quick add plan had. The preview row shows the same facts in the shape the row will have, and the legend teaches the syntax the sentence never showed.
- **`due:` or `on:` as the date trigger.** `@` is one key, pairs with `#`, and needs no grammar change because the pick writes words the grammar already reads.
- **A stacked session list after Enter.** It confirms backdated adds next to the bar, but the operator chose the toast. The toast names the added row, which covers a backdated add that lands below the fold.
- **Hard delete for undo.** `Transaction#discard` already exists, and a hard delete loses data the undo should keep.

## Appendix C. Risks

- **Open decision for the operator.** Can a person pick a future date? Q5 blocks it, matching "where did my money go". The grammar accepts up to one year ahead when the year is typed. Allowing it means one `max` change in `calendar_controller.js`.
- **A literal `@` in a name.** A pasted `@y` skips the calendar and stays in the name. Q5's owner watches whether the grammar should drop a bare `@`.
- **Preview latency on slow hosts.** Q1 measures it. If p95 exceeds 100 milliseconds, raise it before Q2 builds on the frame.
- **Morph and focus.** Q2's spike decides between morph and a permanent bar before the rest of Q2.
- **`Ctrl+Z` in the field.** Q2 binds undo only while the field is empty and the toast shows, so text undo inside the field keeps working.

## Appendix D. Links and reading list

- `app/models/transaction/draft.rb` and `test/models/transaction/draft_test.rb` define the grammar every PR leans on.
- `.claude/skills/verify-moneypouch/SKILL.md` and its `features/` files are the control skill for every lane.
- `app/assets/tailwind/application.css` holds the tokens. Build from the class strings in `app/views/welcome/index.html.erb` and the prototype.
- The closed quick add plan in PR 10 holds the earlier design for morph refresh, idempotency, and time zones.
- Run `/Users/kenlu/kstack/skills-src/how/SKILL.md` before Q2 on Turbo morph, and `/Users/kenlu/kstack/skills-src/interrogate/SKILL.md` on Q2 before merge, since it changes how a row is deleted.
