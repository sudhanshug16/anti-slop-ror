# Research basis

## Layer 1: the six custom cops

[Agents on Rails](https://github.com/rails/ai-evals) evaluates agents on 21 atomic tasks against Writebook. Its grading restores protected surfaces, runs application tests, and runs hidden behavioral checks; it also measures Rails API recall separately. The [first public report](https://railsai.org/research) reports intended Rails API recall of 8–35%; runs that recalled the API solved 92%, hand-rolled runs 87%, and runs that found but ignored it solved 64%.

This project treats that as a design signal, not a claim that linting proves correctness. Benchmark-inspired tasks include unsafe `allow_other_host` redirects, interpolated SQL and LIKE sanitization, nested-resource scoping, transaction nonlocal exit, cache-key dimensions, and job enqueue timing. Only the local AST shapes suitable for a generic cop ship here. Scoping, cache dimensions, enqueue timing, schemas, routes, and behavioral tests remain research backlog.

Primary references: [Rails security guide](https://guides.rubyonrails.org/security.html), [Rails Active Record transactions](https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html), [StandardRB](https://github.com/standardrb/standard), [lint_roller](https://github.com/standardrb/lint_roller), [RuboCop](https://docs.rubocop.org/rubocop/), [RuboCop Rails](https://docs.rubocop.org/rubocop-rails/), and [Brakeman warning types](https://brakemanscanner.org/docs/warning_types/).

These six custom AST cops are the reliable default this gem ships, not the total catalog of Rails slop.
They deliberately don't grow to cover everything `rubocop-rails` and Brakeman already check — see
[README.md](../README.md#scope-six-cops-are-the-reliable-default-not-the-catalog) for why the cop count
stays intentionally small (`rubocop-rails` already ships, among others, `Rails/UniqueValidationWithoutIndex`,
`Rails/TransactionExitStatement`, `Rails/SkipsModelValidations`, and `Rails/SaveBang`; Brakeman covers its
own [documented security categories](https://brakemanscanner.org/docs/warning_types/)).

## Layers 2 and 3: the skill's existing-tool orchestration and semantic review

The [`install-anti-slop-ror` skill](../skills/install-anti-slop-ror/SKILL.md) adds two layers the cops
themselves can't provide:

| Layer | What it does | Proves |
| --- | --- | --- |
| 1. Custom cops | Runs the six AST cops above via StandardRB | Six narrow, high-confidence syntactic anti-patterns |
| 2. Existing-tool orchestration | Discovers and runs the target repo's own StandardRB/`rubocop-rails`, Brakeman, and tests; reports gaps instead of assuming untested tools passed | Whatever coverage the target repo already has, honestly reported |
| 3. Semantic review | Reads [`references/rails-review.md`](../skills/install-anti-slop-ror/references/rails-review.md) and inspects the diff for boundaries no linter can prove | Evidence-backed, diff-specific review verdict with disclosed gaps |

Layer 3's reference is grounded in a second, distinct piece of research from the one above: the [LLM
Coding Benchmark's success report](https://github.com/akitaonrails/llm-coding-benchmark/blob/master/docs/success_report.md),
which scores 40 models building an identical Rails/Hotwire/RubyLLM chat app and names concrete,
reproducible failure modes — process-local singleton/class-variable state that breaks under multi-worker
Puma, unbounded session-cookie history, test suites that mock the exact code path they're meant to
verify, stored state that's never replayed, dead Stimulus wiring, and committed secrets or dev-mode
Docker images. That report evaluates one benchmark on one application shape; `rails-review.md` labels
each category as either evidenced by that report or as a general Rails hazard from framework/tooling
documentation, and treats the report as a design signal, not proof the category list is exhaustive or
Rails-universal. Its other primary sources are the [Rails caching
guide](https://guides.rubyonrails.org/caching_with_rails.html), [Rails transaction
callbacks](https://guides.rubyonrails.org/active_record_callbacks.html#transaction-callbacks), [Rails
validations — uniqueness](https://guides.rubyonrails.org/active_record_validations.html#uniqueness),
[Rails security guide](https://guides.rubyonrails.org/security.html), [Rails Active Job
basics](https://guides.rubyonrails.org/active_job_basics.html), the [RuboCop Rails cop
inventory](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html), [Brakeman warning
types](https://brakemanscanner.org/docs/warning_types/), [GitHub's agent pull request review
guidance](https://github.blog/ai-and-ml/generative-ai/agent-pull-requests-are-everywhere-heres-how-to-review-them/),
and [*More Code, Less Reuse*](https://arxiv.org/abs/2601.21276).
