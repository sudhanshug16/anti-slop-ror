# anti-slop-ror

Focused, no-autocorrect RuboCop cops for Rails code where a locally plausible change can silently weaken a safety boundary.

## Installation

The supported default is the self-contained [`install-anti-slop-ror`](skills/install-anti-slop-ror/SKILL.md)
skill. Its installer copies the bundled cops and config into a target without requiring this repository,
a published gem, or a network connection:

```sh
ruby /path/to/install-anti-slop-ror/scripts/install.rb /path/to/rails-app
```

Add the exact `.standard.yml` block it prints, then run
`bundle exec standardrb --raise-cop-error`. The target must already use StandardRB. Vendored installations
are snapshots: rerun with `--force` only when intentionally replacing `tools/anti_slop_ror`. From this
repository, `ruby scripts/install.rb /path/to/rails-app` remains a compatibility shortcut.

RubyGems publication is optional and is not required for the skill workflow. The gemspec and packaged-gem
smoke remain so a conventional Bundler distribution can be published later without changing the cops.

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
of Rails-specific hazards *when their cops are actually enabled*, and duplicating those checks here would
just add noisy, worse-maintained copies for no gain. Notably, `rubocop-rails` ships cops in this space —
`Rails/UniqueValidationWithoutIndex` (uniqueness validations without a matching DB index),
`Rails/TransactionExitStatement` (`return`/`break`/`throw` inside a transaction), `Rails/SkipsModelValidations`
(`update_column`, `update_attribute`, `update_all`, and similar), and `Rails/SaveBang` (unchecked
`save`/`update`/`create` return values), among others — see the [RuboCop Rails cop
inventory](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html). That is not blanket coverage,
though: the `standard-rails` baseline this project targets disables `Rails/SaveBang` and
`Rails/SkipsModelValidations` outright, and `Rails/TransactionExitStatement` is a no-op on Rails >= 7.2
regardless of config. Whether any of these are actually active for a given target depends on its effective
config and Rails version — see [Limitations](#limitations) below and the skill's review mode, which checks
this rather than assuming a gem being present means the cop fired. Brakeman covers its own documented
security categories (SQL injection, XSS, mass assignment, unsafe redirects, CSRF, and more — see [Brakeman
warning types](https://brakemanscanner.org/docs/warning_types/)). This project's cops fill gaps neither
tool checks (request-driven dynamic dispatch, silent rescue, unbounded strong parameters) rather than
re-implementing what already exists.

Because most high-value Rails failures are semantic or runtime, not syntactic, the
[`install-anti-slop-ror` skill](skills/install-anti-slop-ror/SKILL.md) also runs two more layers:
orchestrating the target repo's own existing safety tools, and a semantic review pass for what no AST cop
can prove. Reviewing a diff does **not** require installing these cops first: the skill's review mode runs
read-only against whatever the target repo already has and reports any of these six cops (or other
tooling) that aren't installed as a gap in the verdict, rather than installing them.

| Layer | What it does | Proves |
| --- | --- | --- |
| 1. Custom cops (install mode) | Runs these six AST cops via StandardRB | Six narrow, high-confidence syntactic anti-patterns |
| 2. Existing-tool coverage (review mode, read-only) | Discovers and runs the target repo's own StandardRB/`rubocop-rails`, Brakeman, and tests as already configured; checks whether specific named cops are actually enabled and applicable rather than assuming a gem's presence means coverage; reports anything missing, disabled, or unverified | Whatever coverage the target repo *actually* has active, honestly reported |
| 3. Semantic review (review mode) | Reads [`references/rails-review.md`](skills/install-anti-slop-ror/references/rails-review.md) and inspects the diff for boundaries no linter can prove (state loss, stub drift, transaction/job timing, cache keys, scoping, guardrail weakening, and more) | Evidence-backed, diff-specific review verdict with disclosed gaps |

## Limitations

The cops are AST-local. They do not follow aliases, prove routes or schemas, understand runtime SQL, or replace tests. A closed constant mapping such as `handler.public_send(HANDLERS.fetch(params[:kind]))` is intentionally permitted before dispatch. A variable kwsplat such as `**options` is not evaluated for redirect safety. Constant-only SQL interpolation is reported because the linter cannot establish its value safely; suppress locally when reviewed.

StandardRB configures `Lint/SuppressedException` differently, so this cop intentionally tightens its silent-rescue boundary there. Plain RuboCop users may see overlap with that built-in cop. RSpec verified-double checks remain existing-tool coverage; the semantic hazards `rubocop-rails` and Brakeman don't check (state persistence, stub/contract drift, transaction/job timing, cache-key dimensions, nested-resource scoping) are covered by the skill's Layer 3 review, not a cop, because they require semantic or runtime evidence an AST pass can't produce.

## Development

`bundle install`, `bin/sync-skill-assets`, and `bin/check` are the normal loop. `bin/check` runs StandardRB with `--raise-cop-error`, specs, and asset-drift verification.

## Evidence

Rule boundaries and research links are in [docs/research.md](docs/research.md) and [docs/rule-design.md](docs/rule-design.md). Primary sources include [Rails security](https://guides.rubyonrails.org/security.html), [StandardRB plugins](https://github.com/standardrb/standard), [lint_roller](https://github.com/standardrb/lint_roller), [RuboCop Rails](https://docs.rubocop.org/rubocop-rails/), [RuboCop](https://docs.rubocop.org/rubocop/), [Brakeman](https://brakemanscanner.org/docs/), and [Agents on Rails](https://github.com/rails/ai-evals).
