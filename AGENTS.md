# Agent rules

Each rule names what enforces it. A rule enforced by a check needs no reading: run `bin/ci` (or `bin/rails test`, `bin/rubocop`, `npx herb-lint`) and fix what fails. A rule marked "Review" is a judgment call nothing checks, so read those before writing code.

When the operator corrects you, fix the mistake and add its rule here. If the rule was already here and nothing enforces it, that is a repeat: add a check in the same change. Drop a rule once its mistake can't happen.

| Rule | Enforced by |
|------|-------------|
| No comments, none at all. Say it with a name instead. Only the comments Rails and the gem installers generate stay. | Review |
| The verify-moneypouch feature map names only code that exists. A change that renames or removes a constant, method, route, or file updates `.claude/skills/verify-moneypouch/features/` in the same commit. | `test/lint/feature_map_test.rb` for names. Review for copy, selectors, and behavior: drive the feature with the skill. |
| Methods are multiline `def ... end`, never endless. | RuboCop `Style/EndlessMethod` |
| No `and`/`or` control flow. | RuboCop `Style/AndOr` |
| Control flow is if/else or an early return, never `x \|\| raise` or `x && return`. | Review |
| Three or more branches on one value is `case`/`when`. | RuboCop `Style/CaseLikeIf` |
| Colors come from the semantic tokens. | `.herb/rules/colors.mjs` |
| Type comes from the roles and the scale, never pixel fonts, tracking, or bracketed sizes. | `.herb/rules/typography.mjs` |
| Trends and Overview never frame spending as bad news. | `test/integration/trends_tone_test.rb` |
| Tell, don't ask: never write another class's columns, chain through its associations, or reach into its state. Add an intention-revealing method on the owner. | Review |
| No service objects (`Categorizer#categorize`). Behavior lives on the model that owns the data; check basecamp/fizzy for precedent. | Review |
| Name things with the words the UI and the user say (`BankTransaction`, not `Line` or `Entry`). No accounting jargon. | Review |
| Plans live outside the repo, never in `docs/plans`. What lasts goes in the feature map. | Review |
