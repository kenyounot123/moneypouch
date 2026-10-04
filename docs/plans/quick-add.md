# Quick add plan

MoneyPouch turns the Overview mockup into a working expense tracker whose core loop is one typed line per purchase.
A person types `coffee 5.50 yesterday`, sees how it was read, presses Enter, and the dashboard updates.
The rule the program enforces is that one parser decides what a line means, for the preview, the save, and every later edit.
No budgets, goals, or bank sync land in this program.
The PR ids in order are P0 to P9. P0 lands this plan, the design, and the sketch.
The code shape is fixed in [quick-add-design.md](quick-add-design.md) and [quick-add-sketch/](quick-add-sketch/). Owners implement against the sketch and raise any deviation as a finding.

## How to read this

One box is one unit of work. Every box names the evidence that checks it. A nested box is a sub-step of the box above it. Check a box only when its evidence exists, a file, a log line, a screenshot, a test run, or a SHA. The body is a how-to. The appendices explain and record.

The program runs `kstack/skills/k-mode/playbooks/autopilot-stack.md` (on this machine `/Users/kenlu/kstack/skills-src/k-mode/playbooks/autopilot-stack.md`). The work is sequenced and the operator reviews before landing, so no agent merges. The root appends each verified PR to one linear stack on `main` and the operator lands it bottom-up. The operator may take any PR as its owner and write the code personally. The root then only verifies and appends.

Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

## Program checklist

### Arm the program

- [ ] State the protocol and this plan to the operator, then stop. Start execution only on their explicit go.
- [ ] On their go, arm a `/goal` with this exact text. "Run docs/plans/quick-add.md under autopilot-stack. Build P0 to P9 in order as one linear stack on main. A PR is verified only when its unit, live, and perf boxes are all checked. No agent merges. The operator reviews and lands every PR. Done when P0 to P9 each carry a clean swarm verdict at their head SHA and sit in the stack."
- [ ] Read these at program start. Re-read them at every tick.
  - [ ] `cat /Users/kenlu/kstack/skills-src/k-mode/playbooks/autopilot-stack.md`
  - [ ] `cat /Users/kenlu/kstack/skills-src/swarm/SKILL.md`
  - [ ] `git show origin/main:.claude/skills/verify-moneypouch/SKILL.md` once P1 is in the stack. Before that, read it from the P1 branch.
  - [ ] `cat /Users/kenlu/kstack/skills-src/k-mode/playbooks/opening-a-pr.md`
  - [ ] `cat /Users/kenlu/kstack/skills-src/rails-best-practices/SKILL.md`
  - [ ] `cat /Users/kenlu/kstack/skills-src/create-verification-skill/SKILL.md` for P1.
- [ ] Arm the 30-minute audit tick. In a local session, a real terminal `/loop`. In a cloud root, a cloud-sleeper wake chain. Never leave the cadence to memory.
- [ ] Use this tick prompt, verbatim. "Re-read the execution playbook from trunk and the armed /goal. Audit the operation against both and fix drift in this tick. Probe every active lane and judge progress by side effects only. Stand down a stuck lane and dispatch its replacement now. Then send the operator a status message, whether or not anything changed, with the queue table of PR, owner, state, and head SHA, the verdicts since the last tick, what merged, open operator gates, and blockers."
- [ ] On the operator's hold or stand-down, send every owner a zero-writes order at once.

### Spawn owners

- [ ] Spawn one owner per PR with the full lifecycle the execution playbook names.
- [ ] Follow this dependency graph. Base each branch on its parent branch, since the program stacks.
  - [ ] P0 is first. It branches from `main` and touches only `docs/`.
  - [ ] P1 after P0.
  - [ ] P2 after P1. P3 after P2. P4 after P3. P5 after P4.
  - [ ] P6, P7, and P8 each depend only on P5. They build in parallel and append in that order.
  - [ ] P9 after P7 and P8.
- [ ] Hold the file boundaries.
  - [ ] P1 touches only `.claude/`, `db/seeds.rb`, and `lib/tasks/`.
  - [ ] P2 touches only `app/views/transactions/`, `app/controllers/transactions_controller.rb`, `app/javascript/controllers/hello_controller.js`, `config/routes.rb`, `Gemfile`, `Gemfile.lock`, and `test/`.
  - [ ] P3 touches only `db/`, `app/models/`, `lib/tasks/`, and `test/`.
  - [ ] P4 touches only `app/models/draft.rb` and `test/models/draft_test.rb`.
  - [ ] P5 to P9 touch only `app/`, `config/routes.rb`, and `test/`.
- [ ] Hold the review gate. P5, P6, P7, P8, and P9 change an interaction. They wait for the operator's review in chat with screenshots and a video before merge.

### PR mechanics, for every PR

- [ ] Resolve the forge once. Default to `gh`; if `command -v origin` succeeds and Origin can resolve the repository, use `origin pr` for every PR operation. Record any fallback to `gh`. Never require `gt`.
- [ ] Open the PR ready, never draft, with `origin pr create --status open --base <base-branch>` or `gh pr create --base <base-branch>` according to the resolved forge. A stack child targets its parent branch.
- [ ] Run `bin/ci` once before the PR-facing push. It runs rubocop, bundler-audit, importmap audit, brakeman, the Rails tests, and the seed replant. Push with hooks on.
- [ ] Run `/no-comments` and `principle-laziness-protocol` over the diff before each commit, and `/no-comments` before review.
- [ ] Triage every Bugbot and security-reviewer comment per `/Users/kenlu/kstack/skills-src/k-mode/references/bugbot-triage.md`.
- [ ] Rebase onto current trunk before babysit and again before the merge-ready report.

### Verdict and merge, for every PR

- [ ] At the merge-ready head SHA, run the swarm per `/Users/kenlu/kstack/skills-src/swarm/SKILL.md`. One gates lane. The ten live lanes from the PR's **Verify, live** block. The perf lane from its **Verify, perf** block. One audit lane that reads the diff and the receipts and distrusts the PR body.
- [ ] Clean only when every lane is `PASS`. Findings go back to the owner. A new head gets a fresh swarm and a fresh verdict.
- [ ] Append on a clean verdict. Rebase the child onto its parent's exact tip and compare `git patch-id` against the verdict SHA. An unchanged patch-id keeps the verdict. A changed one goes back through the swarm. The operator lands the stack bottom-up.

### Boot recipe, for every live lane

Each live lane runs in its own remote subagent at the PR head. Drive through the repo's `verify-moneypouch` skill, which P1 builds with the **create-verification-skill** skill.

- [ ] `git fetch origin <head-branch> && git checkout <head SHA>`.
- [ ] Run `bin/setup --skip-server`, then `bin/rails db:seed`, then start `bin/dev` on a free port. Wait until `curl -s localhost:<port>/up` returns 200.
- [ ] Sign in as the seed user from `db/seeds.rb` and deliver every keypress and click through the `verify-moneypouch` commands. Read-only diagnostics are `log/development.log`, `bin/rails runner` queries, and the browser console.
- [ ] Save every screenshot to `/tmp/swarm-<pr-id>/worker-<n>/<slug>.png` and return the paths with the report.

## Land the plan and the design (P0)

**Depends on.** None.

**Files.**

- [ ] Add `docs/plans/quick-add.md`, `docs/plans/quick-add-design.md`, and `docs/plans/quick-add-sketch/`.

**Verify.** P0 changes no code. Its gate is `bin/ci` green and a reviewer reading the design. It gets no live or perf lanes.

**Review gate.** The operator reads the design before P1 builds on it.

## Build the verify-moneypouch control skill (P1)

**Depends on.** P0.

**Files.**

- [ ] Create `.claude/skills/verify-moneypouch/SKILL.md` with the **create-verification-skill** skill.
- [ ] Create `.claude/launch.json` with a `moneypouch` entry that runs `bin/dev`.
- [ ] Edit `db/seeds.rb`.

**Build.**

- [ ] Make `db/seeds.rb` create the `demo` user idempotently with `User.find_or_create_by!`. The test password lives in the seed file only.
- [ ] Write the skill so an agent can boot the app, sign in as `demo`, type into a field, press a key, take a screenshot, and read a query result, with one command each.

**You see.**

- [ ] Running the skill's boot command twice prints the same signed-in Overview URL both times and leaves one `demo` user.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Run `env RAILS_ENV=test bin/rails db:seed:replant` twice. Both runs exit 0.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Boot and sign in at trunk and head. Trunk has no control skill, so record that and gate the head reaching the signed-in Overview. Save `overview.png`. Pass when the head screenshot shows the sidebar and the quick add bar.
- [ ] Lane 2. Boot from a fresh clone with no database. Save `fresh-boot.png`. Pass when the skill reaches the signed-in Overview with no manual step.
- [ ] Lane 3. Run the boot command twice in a row. Save `second-boot.png`. Pass when `User.where(username: "demo").count` is 1.
- [ ] Lane 4. Type `hello` into the quick add field through the skill. Save `typed.png`. Pass when the field shows `hello`.
- [ ] Lane 5. Press Enter through the skill and read `log/development.log`. Save `enter.png`. Pass when the log shows the key event reached the page.
- [ ] Lane 6. Sign out and sign back in with a wrong password. Save `wrong-password.png`. Pass when the page shows the existing alert text.
- [ ] Lane 7. Switch to dark mode through the skill. Save `dark.png`. Pass when the screenshot is dark and `html[data-theme]` reads `dark`.
- [ ] Lane 8. Resize to 375 by 812 and screenshot. Save `phone.png`. Pass when the page has no horizontal scroll.
- [ ] Lane 9. Run a read-only query through the skill. Save `query.png`. Pass when the output prints the transaction count.
- [ ] Lane 10. Boot two instances on two ports at once. Save `two-ports.png`. Pass when both reach the Overview.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Seconds from the boot command to the signed-in Overview screenshot. Trunk has no boot command, so this is an absolute budget.
- [ ] Probe. Run the boot command five times from a stopped server and time each run.
- [ ] Baseline. Record trunk as having no measurement and say so in the report.
- [ ] Rule. Fail when the median exceeds 60 seconds.

**Review gate.** None. P1 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends P1 to the stack and the operator lands it bottom-up.

## Remove the unused transaction scaffold (P2)

**Depends on.** P1.

**Files.**

- [ ] Delete `app/views/transactions/new.html.erb`, `edit.html.erb`, `show.html.erb`, `_form.html.erb`, `_transaction.json.jbuilder`, `index.json.jbuilder`, and `show.json.jbuilder`.
- [ ] Delete `app/javascript/controllers/hello_controller.js`.
- [ ] Edit `app/controllers/transactions_controller.rb`, `config/routes.rb`, `Gemfile`, and `test/controllers/transactions_controller_test.rb`.

**Build.**

- [ ] Route `resources :transactions, only: %i[ index create update destroy ]`.
- [ ] Drop the `new`, `show`, and `edit` actions and every `format.json` branch from `TransactionsController`.
- [ ] Remove `jbuilder` from the `Gemfile` once nothing renders JSON with it.
- [ ] Delete the controller tests for removed actions. Keep index, create, update, and destroy tests.

**You see.**

- [ ] `bin/rails routes -g transactions` lists exactly four routes.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `test/controllers/transactions_controller_test.rb` keeps four passing cases. Run `bin/rails test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Load the Overview at trunk and head. Save `overview.png`. Pass when both screenshots match pixel for pixel.
- [ ] Lane 2. Visit `/transactions/new` at head. Save `new-404.png`. Pass when the response is 404.
- [ ] Lane 3. Visit `/transactions/1` at head. Save `show-404.png`. Pass when the response is 404.
- [ ] Lane 4. Visit `/transactions` at head. Save `index.png`. Pass when the page renders with status 200.
- [ ] Lane 5. Toggle dark mode at head. Save `dark.png`. Pass when the theme still switches.
- [ ] Lane 6. Sign out and back in at head. Save `signin.png`. Pass when the Overview loads.
- [ ] Lane 7. Grep the head tree for `hello`, `jbuilder`, and `new_transaction_path`. Save `grep.png`. Pass when nothing matches outside `Gemfile.lock` history.
- [ ] Lane 8. Load the Overview at phone width at head. Save `phone.png`. Pass when it matches trunk.
- [ ] Lane 9. Read the browser console on the Overview at head. Save `console.png`. Pass when it has no errors.
- [ ] Lane 10. Run `bin/ci` at head. Save `ci.png`. Pass when every step is green.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Server time for `GET /` from `log/development.log`, and wall time for `bin/rails test`.
- [ ] Probe. Alternate trunk and head five times each, warm.
- [ ] Baseline. Record the trunk medians first.
- [ ] Rule. Fail when either head median is more than 10 percent above trunk.

**Review gate.** None. P2 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends P2 to the stack and the operator lands it bottom-up.

## Give transactions their real shape (P3)

**Depends on.** P2.

**Files.**

- [ ] Create a migration under `db/migrate/` for `categories`.
- [ ] Create a migration under `db/migrate/` for the new `transactions` columns.
- [ ] Create `app/models/category.rb`.
- [ ] Edit `app/models/transaction.rb`, `app/models/user.rb`, `test/fixtures/transactions.yml`, and `db/seeds.rb`.
- [ ] Create `test/fixtures/categories.yml` and `lib/tasks/dev.rake`.

**Build.**

- [ ] Create `categories` with `user_id` and `name`, both `null: false`, and a unique index on `user_id, lower(name)`.
- [ ] Add to `transactions` the columns `name` (string), `occurred_on` (date), `category_id` (nullable reference), `line` (text, nullable), `discarded_at` (datetime, nullable), and `idempotency_key` (string, nullable). Backfill `occurred_on` from `created_at` and `name` from an empty string, then set `name`, `occurred_on`, `amount_in_cents`, and `currency` to `null: false`. Default `currency` to `USD`.
- [ ] Index `transactions` on `user_id, occurred_on`, on `user_id, lower(name), occurred_on` where `discarded_at IS NULL`, and uniquely on `user_id, idempotency_key` where it is not null.
- [ ] Store `amount_in_cents` signed. Money out is negative and money in is positive, matching SimpleFIN.
- [ ] Add `Transaction.kept`, `Transaction.discarded`, `#discard`, `#restore`, and `#stashed_on`. Make `User#transactions` kept-only and add `User#discarded_transactions`, so no read can see a discarded row.
- [ ] Add `rake dev:transactions[N]` to create N realistic transactions for `demo` across the last 12 months.

**You see.**

- [ ] `bin/rails db:migrate` runs on a database holding rows, and `bin/rails db:rollback` reverses it.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `test/models/transaction_test.rb` gains a case that a discarded transaction is missing from `kept` and returns after `restore`. Run `bin/rails test test/models`.
- [ ] `test/models/category_test.rb` gains a case that `Food` and `food` for one user fail the unique index. Run `bin/rails test test/models`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Load the Overview at trunk and head. Save `overview.png`. Pass when both screenshots match.
- [ ] Lane 2. Migrate a copy of a database holding 3 trunk-shaped rows. Save `migrated.png`. Pass when all 3 rows keep their amounts and gain an `occurred_on`.
- [ ] Lane 3. Roll the migration back and forward again. Save `rollback.png`. Pass when both directions exit 0 and the row count is unchanged.
- [ ] Lane 4. Run `rake dev:transactions[10000]`. Save `bulk.png`. Pass when the count is 10000 and dates span 12 months.
- [ ] Lane 5. Run `rake dev:transactions[100]` twice. Save `bulk-twice.png`. Pass when it adds 200 rows and no category is duplicated.
- [ ] Lane 6. Create category `Food` then `food` for `demo` in the runner. Save `case.png`. Pass when the second raises a uniqueness error.
- [ ] Lane 7. Create category `Food` for two different users. Save `two-users.png`. Pass when both succeed.
- [ ] Lane 8. Discard one transaction and count `kept`. Save `discard.png`. Pass when the count drops by 1 and the row still exists.
- [ ] Lane 9. Try saving a transaction with no `occurred_on`. Save `not-null.png`. Pass when the database rejects it.
- [ ] Lane 10. Run `bin/ci`. Save `ci.png`. Pass when every step is green.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Seconds to run the migration on a database with 10000 trunk-shaped rows, and server time for `GET /`.
- [ ] Probe. Restore the same database copy before each migration run, five runs. Alternate `GET /` on trunk and head five times each.
- [ ] Baseline. Record the trunk `GET /` median first. Trunk has no migration, so record that.
- [ ] Rule. Fail when the migration median exceeds 5 seconds or the head `GET /` median is more than 10 percent above trunk.

**Review gate.** None. P3 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends P3 to the stack and the operator lands it bottom-up.

## Parse a typed line into a transaction (P4)

**Depends on.** P3.

**Files.**

- [ ] Create `app/models/draft.rb`.
- [ ] Create `test/models/draft_test.rb`.

**Build.**

- [ ] Add `Draft.parse(line, user:, today:, excluding: nil)`, which returns a `Draft` holding `name`, `amount_in_cents`, `category`, `occurred_on`, and `errors`. It never writes to the database. Its pure core is `Draft::Grammar.read(line, today:)`, returning a `Draft::Reading`, and it makes at most one query, for the category.
- [ ] Read the amount from the first token shaped like `5`, `5.50`, or `$5.50`. A leading `+` means money in. Every other amount is money out.
- [ ] Read the category from a `#word` token. With no `#word`, use the category of this user's latest kept transaction with the same name, ignoring case.
- [ ] Read the date from `today`, `yesterday`, a weekday name meaning the latest one on or before today, `sep 26`, `9/26`, or `2026-09-26`. A month and day with no year means the latest past occurrence. No date means today.
- [ ] Join the remaining words into `name`.
- [ ] Add `Draft#attributes` returning the hash `Transaction` saves, with `line` set to the original line.
- [ ] Set `errors` to `Add an amount` when no amount is found and `Add a name` when no words remain.

**You see.**

- [ ] `bin/rails runner 'p Draft.parse("coffee 5.50 yesterday", user: User.first, today: Date.new(2026, 9, 27)).attributes'` prints name `coffee`, amount `-550`, and date `2026-09-26`.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `test/models/draft_test.rb` gains one case per grammar rule above, each asserting the literal attributes hash for a literal input and a fixed `today`. Run `bin/rails test test/models/draft_test.rb`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Run the `You see` runner command at trunk and head. Trunk has no `Draft`, so record the error and gate the head output. Save `parse.png`. Pass when the head prints `coffee`, `-550`, and `2026-09-26`.
- [ ] Lane 2. Parse `+2000 paycheck` through the runner. Save `income.png`. Pass when the amount is `200000`.
- [ ] Lane 3. Parse `lunch $12 #food friday` with today on a Sunday. Save `weekday.png`. Pass when the date is the Friday two days earlier and the category is `food`.
- [ ] Lane 4. Parse `monday 9.99 spotify` with today on a Monday. Save `same-weekday.png`. Pass when the date is today.
- [ ] Lane 5. Parse `dec 30 gift 40` with today on 2027-01-02. Save `year-wrap.png`. Pass when the date is 2026-12-30.
- [ ] Lane 6. Parse `coffee` with no amount. Save `no-amount.png`. Pass when errors equal `Add an amount`.
- [ ] Lane 7. Parse `5.50` with no words. Save `no-name.png`. Pass when errors equal `Add a name`.
- [ ] Lane 8. Save one `Blue Bottle 5 #food`, then parse `blue bottle 6`. Save `inferred.png`. Pass when the category is `Food`.
- [ ] Lane 9. Parse `5.5.5 thing` and `$ coffee`. Save `junk.png`. Pass when neither raises and both report `Add an amount`.
- [ ] Lane 10. Parse the same line 100 times and count transactions. Save `no-writes.png`. Pass when the transaction count is unchanged.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Mean microseconds per `Draft.parse` call with 10000 transactions in the database. Trunk has no parser, so this is an absolute budget.
- [ ] Probe. Run 10000 parses of 20 mixed inputs in `bin/rails runner` with `Benchmark.realtime`, three times.
- [ ] Baseline. Record trunk as having no parser and say so in the report.
- [ ] Rule. Fail when the median mean exceeds 2 milliseconds per call.

**Review gate.** None. P4 is not review-gated.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends P4 to the stack and the operator lands it bottom-up.

## Save a typed line from the quick add bar (P5)

**Depends on.** P4.

**Files.**

- [ ] Create `app/controllers/drafts_controller.rb`, `app/views/drafts/show.html.erb`, `app/views/drafts/_draft.html.erb`, `app/views/drafts/_error.html.erb`, `app/views/shared/_quick_add.html.erb`, `app/views/transactions/change.turbo_stream.erb`, and `app/models/month.rb`.
- [ ] Create `app/javascript/controllers/quick_add_controller.js`, `app/javascript/controllers/time_zone_controller.js`, and `app/javascript/controllers/support/write.js`.
- [ ] Create `app/views/transactions/_transaction.html.erb` from the Recent row markup in `app/views/welcome/index.html.erb`.
- [ ] Edit `app/views/welcome/index.html.erb`, `app/controllers/transactions_controller.rb`, `app/controllers/application_controller.rb`, `app/views/layouts/application.html.erb`, and `config/routes.rb`.

**Build.**

- [ ] Set a `time_zone` cookie from the browser, copying the cookie pattern in `background_controller.js`. Compute `today` in that zone in `ApplicationController`.
- [ ] Add `GET /draft?line=`, rendered into `<turbo-frame id="draft">` under the bar. It reads the line with `Transaction#draft` and shows the read-back sentence, such as `Spent $5.50 on coffee, yesterday · Food`, or the first error in `text-danger`. The sentence replaces the mockup's pills, per prototype flow 2.
- [ ] Make `quick_add_controller` set the frame's `src` on each input event. Turbo cancels the stale request, so only the latest line paints.
- [ ] Make Enter post `line` and an `idempotency_key` through `support/write.js` to `TransactionsController#create`, which calls `Transaction#stash`. A first-use category saves with the row. The field is read-only while the request is in flight. A repeated key returns the existing row.
- [ ] Respond with `transactions/change.turbo_stream.erb`, which carries the undo entry and toast, then morph-refresh the page with `Turbo.visit(location.href, { action: "replace" })`. Clear the field. Respond to an invalid line with the error in the read-back and keep the text.
- [ ] Add `Month` per the sketch, so P6 and P7 share it.
- [ ] Render Recent from the 5 latest kept transactions using `_transaction.html.erb`.

**You see.**

- [ ] Typing `coffee 5.50 yesterday` reads back `$5.50`, the inferred category or `Uncategorized`, and yesterday. Enter adds the row to the top of Recent and empties the field.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `test/controllers/transactions_controller_test.rb` gains a case that posting `coffee 5.50` creates one transaction with amount `-550` and line `coffee 5.50`. Run `bin/rails test`.
- [ ] `test/controllers/drafts_controller_test.rb` gains a case that the draft for `coffee` contains `Add an amount`. Run `bin/rails test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Type `coffee 5.50 yesterday` and press Enter at trunk and head. Trunk shows static pills and saves nothing, so record that and gate the head result. Save `stash.png`. Pass when the head shows a new top row `coffee` at `$5.50` and one new database row.
- [ ] Lane 2. Type one character at a time and screenshot after each. Save `preview-steps.png`. Pass when the read-back always matches the text typed so far.
- [ ] Lane 3. Type `coffee` and press Enter. Save `error.png`. Pass when the bar shows `Add an amount`, keeps `coffee`, and saves nothing.
- [ ] Lane 4. Press Enter three times fast on a valid line. Save `triple-enter.png`. Pass when exactly one transaction is created.
- [ ] Lane 5. Set the browser zone to `America/Los_Angeles` at 23:30 local and stash `tea 3 today`. Save `zone.png`. Pass when the date is the local date, not the UTC date.
- [ ] Lane 6. Stash `+2000 paycheck`. Save `income.png`. Pass when Recent shows it as money in.
- [ ] Lane 7. Stash `lunch 12 #newcat`. Save `new-category.png`. Pass when category `newcat` exists once and the row shows it.
- [ ] Lane 8. Stash a line at phone width. Save `phone.png`. Pass when the bar, read-back, and new row fit with no horizontal scroll.
- [ ] Lane 9. Stash a line in dark mode. Save `dark.png`. Pass when the read-back and row use the dark tokens.
- [ ] Lane 10. Stop the server, press Enter, then start it again. Save `offline.png`. Pass when the bar keeps the text, shows a failure, and nothing is saved twice after a retry.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Milliseconds from keypress to updated read-back, and from Enter to the new row painted, with 10000 transactions. Trunk has neither, so these are absolute budgets.
- [ ] Probe. Drive 50 keypresses and 20 saves through the control skill and read timings from `performance.now()` marks.
- [ ] Baseline. Record that trunk has no live preview or save and say so in the report.
- [ ] Rule. Fail when the keypress p95 exceeds 100 milliseconds or the save p95 exceeds 300 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1, 3, and 8 screenshots into `docs/plans/media/P5-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of typing and saving three lines. Save it as `docs/plans/media/P5-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends P5 to the stack and the operator lands it bottom-up.

## Show real spending on the Overview (P6)

**Depends on.** P5.

**Files.**

- [ ] Create `app/models/spending.rb`.
- [ ] Edit `app/views/welcome/index.html.erb`, `app/controllers/welcome_controller.rb`, `app/models/transaction.rb`, and `app/views/shared/_sidebar.html.erb`.

**Build.**

- [ ] Add `Spending`, with `Spending::Share`, `Spending::Day`, and `Spending::Comparison`. One grouped query over kept money-out transactions in the previous and current month yields the total, the share per category, the total per day, and the change against the same days of last month. The sidebar count is one `pick` query, with no `Span` class.
- [ ] Replace every hard-coded number and row in the Overview and the sidebar entry count with those values, keeping the existing markup and classes.
- [ ] Remove the Week, Month, and Year buttons, since only the month view exists.
- [ ] Show the empty state when the user has no transactions. It reads `Nothing stashed yet. Type what you spent above, like coffee 5.50.`

**You see.**

- [ ] With the `dev:transactions` data, the Overview total equals the runner sum of this month's money-out amounts.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `test/controllers/welcome_controller_test.rb` gains a case with three fixture transactions that asserts the rendered total `$20.50`. Run `bin/rails test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Load the Overview with 10000 transactions at trunk and head. Trunk shows the static mockup, so record that and gate the head numbers. Save `overview.png`. Pass when the head total, category rows, and daily bars match runner queries.
- [ ] Lane 2. Load the Overview for a new user with no transactions. Save `empty.png`. Pass when the empty state shows and nothing reads `$0.00` in a broken layout.
- [ ] Lane 3. Stash `coffee 5` on the Overview. Save `live-total.png`. Pass when the total rises by `$5.00` after the save.
- [ ] Lane 4. Stash `+2000 paycheck`. Save `income-excluded.png`. Pass when the spending total is unchanged.
- [ ] Lane 5. Discard a transaction in the runner and reload. Save `discarded.png`. Pass when the total drops by its amount.
- [ ] Lane 6. Seed 12 categories. Save `many-categories.png`. Pass when every row fits and shares add up to 100 percent within rounding.
- [ ] Lane 7. Load on the 1st of a month. Save `first-day.png`. Pass when the comparison text and the pace bar render without errors.
- [ ] Lane 8. Load at phone width. Save `phone.png`. Pass when there is no horizontal scroll.
- [ ] Lane 9. Load in dark mode. Save `dark.png`. Pass when every bar uses the data tokens.
- [ ] Lane 10. Sign in as a second user with different data. Save `isolation.png`. Pass when no number from `demo` appears.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Server time for `GET /` with 10000 transactions.
- [ ] Probe. Alternate trunk and head five times each, warm, reading `log/development.log`.
- [ ] Baseline. Record the trunk median first. Trunk renders static markup, so it is a floor, not a peer.
- [ ] Rule. Fail when the head median exceeds 150 milliseconds or issues more than 6 SQL queries.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1, 2, and 8 screenshots into `docs/plans/media/P6-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of stashing two lines and watching the Overview change. Save it as `docs/plans/media/P6-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends P6 to the stack and the operator lands it bottom-up.

## List every transaction by day (P7)

**Depends on.** P5.

**Files.**

- [ ] Edit `app/views/transactions/index.html.erb`, `app/controllers/transactions_controller.rb`, and `app/views/shared/_sidebar.html.erb`.

**Build.**

- [ ] Render kept transactions for one month, grouped by `occurred_on` with a daily total, newest first, using `_transaction.html.erb`.
- [ ] Add previous and next month links driven by a `month` parameter.
- [ ] Render `shared/_quick_add` at the top.
- [ ] Point the sidebar Transactions link at `transactions_path` and mark it current there.

**You see.**

- [ ] `/transactions` shows this month's transactions grouped under day headings, and stashing a line adds it under the right day.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `test/controllers/transactions_controller_test.rb` gains a case that `month=2026-08` lists an August fixture and omits a September one. Run `bin/rails test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Open `/transactions` at trunk and head. Trunk shows the scaffold list, so record that and gate the head grouping. Save `list.png`. Pass when the head groups by day and the day totals match runner sums.
- [ ] Lane 2. Click the previous month link. Save `prev-month.png`. Pass when only last month's rows show.
- [ ] Lane 3. Open a month with no transactions. Save `empty-month.png`. Pass when an empty state shows and the month links still work.
- [ ] Lane 4. Stash `tea 3 yesterday` on this page. Save `stash-here.png`. Pass when the row lands under yesterday's heading.
- [ ] Lane 5. Stash `rent 1650 sep 1` while viewing October. Save `other-month.png`. Pass when the October list is unchanged and September shows the row.
- [ ] Lane 6. Visit `?month=garbage`. Save `bad-param.png`. Pass when the page shows the current month with status 200.
- [ ] Lane 7. Open a month with 1500 rows. Save `big-month.png`. Pass when it renders without a timeout and scrolls smoothly.
- [ ] Lane 8. Load at phone width. Save `phone.png`. Pass when there is no horizontal scroll.
- [ ] Lane 9. Load in dark mode. Save `dark.png`. Pass when headings and rows use the dark tokens.
- [ ] Lane 10. Click Transactions then Overview in the sidebar. Save `nav.png`. Pass when the current-page marker follows the page.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Server time for `GET /transactions` for a month holding 1500 transactions.
- [ ] Probe. Alternate trunk and head five times each, warm. Trunk renders every transaction unpaged, which is the comparison.
- [ ] Baseline. Record the trunk median first.
- [ ] Rule. Fail when the head median exceeds 200 milliseconds or exceeds trunk.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1, 3, and 8 screenshots into `docs/plans/media/P7-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of paging months and stashing a line. Save it as `docs/plans/media/P7-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends P7 to the stack and the operator lands it bottom-up.

## Complete names and categories with Tab (P8)

**Depends on.** P5.

**Files.**

- [ ] Create `app/controllers/completions_controller.rb`.
- [ ] Edit `app/javascript/controllers/quick_add_controller.js`, the quick add markup, and `config/routes.rb`.

**Build.**

- [ ] Add `GET /completions` returning the user's distinct kept transaction names with their use count and latest date, and the user's category names.
- [ ] Fetch the list once when the bar gains focus, and again after each save.
- [ ] Find the token under the cursor. A token starting with `#` completes categories. Any other word at the start of the line completes names.
- [ ] Rank prefix matches before contains matches, each by use count then recency, capped at 8.
- [ ] Show the matches in a popup under the bar. Up and Down move. Tab or Enter accepts and replaces the whole token. Esc hides the popup until the next edit. Tab with no popup moves focus as normal.

**You see.**

- [ ] Typing `blu` shows `Blue Bottle` first. Tab turns the line into `Blue Bottle ` and the read-back shows its usual category.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `test/controllers/completions_controller_test.rb` gains a case that a discarded transaction's name is absent and another user's names are absent. Run `bin/rails test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Type `blu` and press Tab at trunk and head. Trunk moves focus away, so record that and gate the head completion. Save `tab.png`. Pass when the head line reads `Blue Bottle ` and focus stays in the bar.
- [ ] Lane 2. Type `#fo` and press Tab. Save `category.png`. Pass when the token becomes `#Food` and the rest of the line is unchanged.
- [ ] Lane 3. Type `ttle`. Save `contains.png`. Pass when `Blue Bottle` appears below every prefix match.
- [ ] Lane 4. Type `blu`, press Esc, then type `e`. Save `esc.png`. Pass when Esc hides the popup and the next character shows it again.
- [ ] Lane 5. Put the cursor inside `#fo` in the middle of a line and accept. Save `mid-line.png`. Pass when only that token is replaced.
- [ ] Lane 6. Type a prefix with more than 8 matches. Save `cap.png`. Pass when exactly 8 show.
- [ ] Lane 7. Stash a new name, then type its first letters. Save `fresh.png`. Pass when the new name is offered without a reload.
- [ ] Lane 8. Type a prefix with no matches and press Enter. Save `no-match.png`. Pass when no popup shows and Enter saves the line.
- [ ] Lane 9. Use the popup at phone width. Save `phone.png`. Pass when the popup fits on screen with no horizontal scroll.
- [ ] Lane 10. Use the popup in dark mode. Save `dark.png`. Pass when the popup and its selected row use the dark tokens.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Milliseconds from keypress to popup painted, and server time for `GET /completions`, with 2000 distinct names. Trunk has neither, so these are absolute budgets.
- [ ] Probe. Drive 50 keypresses through the control skill with `performance.now()` marks, and time `GET /completions` five times warm.
- [ ] Baseline. Record that trunk has no completion and say so in the report.
- [ ] Rule. Fail when the keypress p95 exceeds 16 milliseconds or the endpoint median exceeds 100 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1, 2, and 9 screenshots into `docs/plans/media/P8-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of completing a name and a category. Save it as `docs/plans/media/P8-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends P8 to the stack and the operator lands it bottom-up.

## Drive the app from the keyboard with undo (P9)

**Depends on.** P7 and P8.

**Files.**

- [ ] Create `app/javascript/controllers/keyboard_controller.js` and `app/views/shared/_shortcuts.html.erb`.
- [ ] Create `app/controllers/transactions/restorations_controller.rb`.
- [ ] Edit `app/controllers/transactions_controller.rb`, `app/javascript/controllers/quick_add_controller.js`, `app/views/transactions/_transaction.html.erb`, the layout, and `config/routes.rb`.

**Build.**

- [ ] Ignore every shortcut while focus is in a text field, except Esc.
- [ ] Bind `n` and `/` to focus the quick add bar.
- [ ] Bind `j` and `k` to move a visible selection through the rows on the page.
- [ ] Bind `e` to load the selected row's `line` into the bar. Enter then updates that transaction through `Transaction#stash`. Esc cancels the edit.
- [ ] Bind `dd` within 600 milliseconds to discard the selected row and show `Deleted. Press u to undo.`
- [ ] Bind `u` to undo the latest stash, edit, or delete from a stack of up to 50, via `DELETE /transactions/:id`, `PATCH /transactions/:id` with the previous line, and `POST /transactions/:id/restoration`. The server declares each inverse in `change.turbo_stream.erb`, and a replay sends `undo=1` so it declares none. Restoration reaches only `User#discarded_transactions`.
- [ ] Bind `?` to show the shortcuts overlay, closed by Esc or `?`.

**You see.**

- [ ] Pressing `j`, `dd`, then `u` removes the second row and puts it back in the same place.

**Verify, unit.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] `test/controllers/transactions/restorations_controller_test.rb` gains a case that restoring a discarded transaction returns it to `kept` and that another user's transaction returns 404. Run `bin/rails test`.

**Verify, live.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked. Ten lanes on `sonnet` at the PR head, per the boot recipe.

- [ ] Lane 1. Regression lane against trunk. Press `j`, `dd`, `u` on the Overview at trunk and head. Trunk has no shortcuts, so record that and gate the head result. Save `undo-delete.png`. Pass when the head row disappears, then returns with the same amount and date.
- [ ] Lane 2. Press `n`, stash a line, then press Esc and `u`. Save `undo-stash.png`. Pass when the stashed row is gone and the totals return to their earlier values.
- [ ] Lane 3. Select a row, press `e`, change the amount, press Enter, then `u`. Save `undo-edit.png`. Pass when the row shows the original amount.
- [ ] Lane 4. Type `jjdd` into the quick add bar. Save `typing-safe.png`. Pass when the text is in the bar and no row is deleted.
- [ ] Lane 5. Press `d`, wait one second, press `d`. Save `slow-dd.png`. Pass when nothing is deleted.
- [ ] Lane 6. Delete three rows, then press `u` three times. Save `undo-three.png`. Pass when all three return.
- [ ] Lane 7. Press `?`, then Esc. Save `help.png`. Pass when the overlay lists every shortcut and closes.
- [ ] Lane 8. Delete a row, reload the page, press `u`. Save `undo-after-reload.png`. Pass when nothing changes and the row stays discarded in the database.
- [ ] Lane 9. Press `j` past the last row and `k` past the first. Save `bounds.png`. Pass when the selection stops at the ends.
- [ ] Lane 10. Use `j`, `e`, and `dd` on `/transactions` in dark mode. Save `dark-list.png`. Pass when the selection is visible and every action works.

**Verify, perf.** Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked.

- [ ] Metric. Milliseconds from `j` to the selection painted, and from `dd` or `u` to the list updated. Trunk has no shortcuts, so these are absolute budgets.
- [ ] Probe. Drive 50 `j` presses and 20 delete and undo pairs through the control skill with `performance.now()` marks.
- [ ] Baseline. Record that trunk has no shortcuts and say so in the report.
- [ ] Rule. Fail when the `j` p95 exceeds 16 milliseconds or the delete or undo p95 exceeds 300 milliseconds.

**Review gate.** The operator reviews before merge.

- [ ] Copy lane 1, 3, and 7 screenshots into `docs/plans/media/P9-review-<slug>.png`.
- [ ] Record a 30 to 60 second video of stashing, editing, deleting, and undoing without the mouse. Save it as `docs/plans/media/P9-review.mp4`.
- [ ] Post the screenshots and the video in chat. Stop at merge-ready. Wait for the operator's click.

**Merge.**

- [ ] Root's clean verdict at the exact head SHA.
- [ ] Bugbot triage done.
- [ ] Rebased onto current trunk after the verdict, patch-id unchanged.
- [ ] The root appends P9 to the stack and the operator lands it bottom-up.

## Close the program

- [ ] Every box above is checked with its evidence.
- [ ] Reply to the operator with the report the execution playbook names.

## Appendix A. Prototype evidence

The forks about product scope were calls the operator already made in chat, such as a tracker with no budgets and fast manual entry first.

One prototype ran, for the entry flow. [prototypes/quick-add-flows.html](prototypes/quick-add-flows.html) puts three flows behind one switcher: pills beside the field, a read-back sentence under it, and a draft row inside Recent. Open it with any static server from the repo root. The read-back sentence won. Typing `7 eleven` shows `Spent $7.00 on eleven` before the save, and the sentence still shows at phone width, where the pills were hidden. The prototype's vocabulary switcher settled the names on `Transaction`.

Two questions stay unproven and are gated inside their PRs instead.

- Whether a server round trip per keypress keeps the preview under 100 milliseconds. The P5 perf rule fails the PR if not, and Appendix B names the fallback.
- Whether 2000 names can be filtered in the browser inside one frame. The P8 perf rule fails the PR if not.

## Appendix B. Alternatives rejected

- **A JavaScript copy of the parser for the preview.** Faster per keypress, but two parsers drift, and the preview would stop matching what saves. It becomes the fallback only if the P5 perf rule fails.
- **A starter keyword map, such as coffee to Food.** It makes the first entry feel smarter, but it guesses wrong for many people and is one more thing to maintain. History plus `#category` covers the second entry onward. The operator can reverse this.
- **An AI service to read the line.** It breaks the promise that data stays on the person's machine, and the grammar is small enough to parse locally.
- **Hard delete with a confirm dialog.** A confirm slows every delete and a slip still loses data. `discarded_at` plus undo is faster and safer.
- **A `source` column and a bank `external_id` now.** Nothing writes bank rows in this program. Both land with SimpleFIN sync, where the unique index on `external_id` is a hard requirement.
- **Week and Year views on the Overview.** Removed in P6 to ship one polished month view. They can return as their own PR.
- **A Turbo Stream prepend per write.** It cannot move the Overview totals and needs per-page placement rules. Every write morph-refreshes the page instead. See the design doc.
- **Pills beside the field.** The prototype showed that a read-back sentence exposes misreads like `7 eleven` and works at phone width, where the pills were hidden.
- **A command palette.** Tuxedo has one, but nine shortcuts fit in a `?` overlay. It waits until the action count outgrows the overlay.

## Appendix C. Risks

- **Time zones.** A wrong zone puts `today` on the wrong date for evening entries. P5 owns the cookie, and its lane 5 watches it.
- **Discarded rows leaking into totals.** `User#transactions` is kept-only, so a read through it cannot count deleted spending. A query on `Transaction` directly can. P6 lane 5 and P8 unit tests watch it, and the audit lane greps each diff for `Transaction.` reads.
- **Shortcuts firing while typing.** P9 lane 4 watches it.
- **Undo after a reload.** The undo stack lives in the page, so it ends on reload. P9 lane 8 confirms that nothing breaks. Discarded rows stay in the database either way.
- **Currency.** Every row is `USD` by default. A per-user currency is out of scope.
- **Bank sync later.** When SimpleFIN rows arrive, a stashed coffee and the bank's copy are two rows. Matching them is a separate program and must land before sync writes anything.

## Appendix D. Links and reading list

- The positioning this plan serves is in the operator's memory note `moneypouch-positioning`.
- UX reference is [webstonehq/tuxedo](https://github.com/webstonehq/tuxedo), especially `src/app/autocomplete.rs` for token completion and `src/app/draft.rs` for the add prompt.
- The design system is the published artifact at https://claude.ai/artifact/Hkpax5LWanRsVJ9Xv7F46M and `app/assets/tailwind/application.css`.
- P3 and P4 get `/Users/kenlu/kstack/skills-src/how/SKILL.md` before editing, since they fix the data shape everything else reads.
- P4 and P9 get `/Users/kenlu/kstack/skills-src/interrogate/SKILL.md` before merge, since the grammar and the undo semantics are the contested designs.
- Each owner keeps a `decisions.tsv` trail per `/Users/kenlu/kstack/skills-src/show-me-your-work/SKILL.md`.
