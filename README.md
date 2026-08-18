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

## Limitations

The cops are AST-local. They do not follow aliases, prove routes or schemas, understand runtime SQL, or replace tests. A closed constant mapping such as `handler.public_send(HANDLERS.fetch(params[:kind]))` is intentionally permitted before dispatch. A variable kwsplat such as `**options` is not evaluated for redirect safety. Constant-only SQL interpolation is reported because the linter cannot establish its value safely; suppress locally when reviewed.

StandardRB configures `Lint/SuppressedException` differently, so this cop intentionally tightens its silent-rescue boundary there. Plain RuboCop users may see overlap with that built-in cop. Rails transaction/nonlocal-exit and model-validation cops, RSpec verified-double checks, and Brakeman remain existing-tool coverage or backlog decisions.

## Development

`bundle install`, `bin/sync-skill-assets`, and `bin/check` are the normal loop. `bin/check` runs StandardRB with `--raise-cop-error`, specs, and asset-drift verification.

## Evidence

Rule boundaries and research links are in [docs/research.md](docs/research.md) and [docs/rule-design.md](docs/rule-design.md). Primary sources include [Rails security](https://guides.rubyonrails.org/security.html), [StandardRB plugins](https://github.com/standardrb/standard), [lint_roller](https://github.com/standardrb/lint_roller), [RuboCop Rails](https://docs.rubocop.org/rubocop-rails/), [RuboCop](https://docs.rubocop.org/rubocop/), [Brakeman](https://brakemanscanner.org/docs/), and [Agents on Rails](https://github.com/rails/ai-evals).
