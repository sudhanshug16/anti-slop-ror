# anti-slop-ror

Focused, no-autocorrect RuboCop cops for Rails code where a locally plausible change can silently weaken a safety boundary.

## Installation

Gem users can add `gem "anti-slop-ror"` and configure StandardRB with `plugins: [anti-slop-ror]`. To vendor it, run `ruby scripts/install.rb /path/to/app`, add the exact printed `.standard.yml` block, and run `bundle exec standardrb --raise-cop-error`. Vendored installations are snapshots: rerun the installer to update them. The installer refuses to replace `tools/anti_slop_ror`; use `--force` only when intentionally replacing that snapshot.

| Cop | Rejects |
| --- | --- |
| NoSilentRescue | empty or `nil` rescue bodies |
| NoRequestDrivenDynamicDispatch | direct request-driven `send` or constant lookup |
| NoUnsafeRedirectFromRequest | request-controlled external redirects |
| NoUnboundedStrongParameters | `permit!` and empty strong-parameter contracts |
| NoInterpolatedSql | interpolation or concatenation in SQL calls |
| NoRescueStatementInvalidInTransaction | swallowing `StatementInvalid` in a transaction |

There is **no autocorrect**: each finding needs a human decision.

## Scope: six cops are the reliable default, not the catalog

These six custom AST cops are the reliable default for this gem — not the total catalog of Rails slop.
They stay this small on purpose: `rubocop-rails` and Brakeman already cover a large, well-maintained set
of Rails-specific hazards, and duplicating their checks here would just add noisy, worse-maintained
copies for no gain. Notably, `rubocop-rails` already ships `Rails/UniqueValidationWithoutIndex`
(uniqueness validations without a matching DB index), `Rails/TransactionExitStatement` (`return`/`break`/
`throw` inside a transaction), `Rails/SkipsModelValidations` (`update_column`, `update_attribute`,
`update_all`, and similar), and `Rails/SaveBang` (unchecked `save`/`update`/`create` return values), among
others — see the [RuboCop Rails cop inventory](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html).
Brakeman covers its own documented security categories (SQL injection, XSS, mass assignment, unsafe
redirects, CSRF, and more — see [Brakeman warning types](https://brakemanscanner.org/docs/warning_types/)).
This project's cops fill gaps neither tool checks (request-driven dynamic dispatch, silent rescue,
unbounded strong parameters) rather than re-implementing what already exists.

Because most high-value Rails failures are semantic or runtime, not syntactic, the
[`install-anti-slop-ror` skill](skills/install-anti-slop-ror/SKILL.md) adds two more layers on top of
these cops: orchestrating the target repo's own existing safety tools, and a semantic review pass for
what no AST cop can prove.

| Layer | What it does | Proves |
| --- | --- | --- |
| 1. Custom cops | Runs these six AST cops via StandardRB | Six narrow, high-confidence syntactic anti-patterns |
| 2. Existing-tool orchestration | Discovers and runs the target repo's own StandardRB/`rubocop-rails`, Brakeman, and tests; reports any that are missing rather than assuming they passed | Whatever coverage the target repo already has, honestly reported |
| 3. Semantic review | Reads [`references/rails-review.md`](skills/install-anti-slop-ror/references/rails-review.md) and inspects the diff for boundaries no linter can prove (state loss, stub drift, transaction/job timing, cache keys, scoping, guardrail weakening, and more) | Evidence-backed, diff-specific review verdict with disclosed gaps |

## Limitations

The cops are AST-local. They do not follow aliases, prove routes or schemas, understand runtime SQL, or replace tests. A closed constant mapping such as `handler.public_send(HANDLERS.fetch(params[:kind]))` is intentionally permitted before dispatch. A variable kwsplat such as `**options` is not evaluated for redirect safety. Constant-only SQL interpolation is reported because the linter cannot establish its value safely; suppress locally when reviewed.

StandardRB configures `Lint/SuppressedException` differently, so this cop intentionally tightens its silent-rescue boundary there. Plain RuboCop users may see overlap with that built-in cop. RSpec verified-double checks remain existing-tool coverage; the semantic hazards `rubocop-rails` and Brakeman don't check (state persistence, stub/contract drift, transaction/job timing, cache-key dimensions, nested-resource scoping) are covered by the skill's Layer 3 review, not a cop, because they require semantic or runtime evidence an AST pass can't produce.

## Development

`bundle install`, `bin/sync-skill-assets`, and `bin/check` are the normal loop. `bin/check` runs StandardRB with `--raise-cop-error`, specs, and asset-drift verification.

## Evidence

Rule boundaries and research links are in [docs/research.md](docs/research.md) and [docs/rule-design.md](docs/rule-design.md). Primary sources include [Rails security](https://guides.rubyonrails.org/security.html), [StandardRB plugins](https://github.com/standardrb/standard), [lint_roller](https://github.com/standardrb/lint_roller), [RuboCop Rails](https://docs.rubocop.org/rubocop-rails/), [RuboCop](https://docs.rubocop.org/rubocop/), [Brakeman](https://brakemanscanner.org/docs/), and [Agents on Rails](https://github.com/rails/ai-evals).
