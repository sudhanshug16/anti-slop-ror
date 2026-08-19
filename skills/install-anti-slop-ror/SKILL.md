---
name: install-anti-slop-ror
description: Install and run the anti-slop-ror StandardRB/RuboCop plugin (six AST cops for Ruby on Rails), then orchestrate the project's own Rails safety tools and a semantic review pass to audit AI- or agent-generated Ruby/Rails diffs for slop that linters cannot prove. Use when (1) installing, updating, or vendoring the anti-slop-ror plugin into a Rails repo, (2) reviewing, auditing, or approving an AI agent's Ruby/Rails changes before merge, (3) checking whether a Rails diff introduced silent state loss, untested integration boundaries, weakened CI/security guardrails, or other slop the AST cops cannot catch, or (4) deciding whether a Rails PR is safe to ship.
---

# Anti-slop Rails workflow

Three layers, run in order. Layer 1 is a narrow, reliable AST lint pass — it is not a complete Rails
safety net. Layers 2 and 3 exist because most high-value Rails failures are semantic, repo-specific, or
runtime, not syntactic; do not skip them when the task is "review this Rails diff."

## Layer 1 — install and run the custom cops

The six cops are AST-local, no-autocorrect, and catch narrow, high-confidence anti-patterns: silent
rescue, request-driven dynamic dispatch, unsafe request-controlled redirects, unbounded strong
parameters, interpolated SQL, and swallowed `StatementInvalid` inside a transaction.

1. Vendor or add the gem:
   - Vendor: `ruby scripts/install.rb TARGET` from this repo (refuses to overwrite an existing
     `TARGET/tools/anti_slop_ror`; pass `--force` only to intentionally replace that snapshot).
   - Gem: add `gem "anti-slop-ror"` to the target's Gemfile.
2. Add the printed `.standard.yml` plugin block (the installer prints the exact block; do not
   hand-write it).
3. Run the blocking check: `bundle exec standardrb --raise-cop-error`.
4. Every finding needs a human decision — there is no autocorrect. Do not suppress a finding without
   understanding why the cop fired (see `docs/rule-design.md` in this repo for each cop's intentional
   boundaries).

This layer alone does not establish that a Rails diff is safe. Continue to Layer 2.

## Layer 2 — run the target repo's own Rails safety tools

Discover what the *target* project already has, run it, and report gaps honestly. Never claim a tool
passed if it wasn't run, and never install a new dependency into the target project to close a gap
unless the user explicitly asked for that — this skill orchestrates existing tooling, it does not expand
the target's dependency surface.

1. Inspect the target's `Gemfile`/`Gemfile.lock` (or `bundle list`) for: `standard` / `rubocop`,
   `standard-rails` / `rubocop-rails`, `brakeman`, and a test framework (RSpec/Minitest).
2. For each tool present, run its normal blocking invocation, e.g.:
   - `bundle exec standardrb --raise-cop-error` (covers `rubocop-rails`/`standard-rails` cops too, if
     configured — includes cops like `Rails/UniqueValidationWithoutIndex`,
     `Rails/TransactionExitStatement`, `Rails/SkipsModelValidations`, and `Rails/SaveBang`).
   - `bundle exec brakeman` (or the project's documented invocation).
   - The project's test command (e.g. `bundle exec rspec`, `bin/rails test`).
3. For each tool *absent*, state that plainly in your verdict: "Brakeman is not installed in this repo;
   its security categories were not checked." Do not imply security/lint coverage that didn't run.
4. If tests fail or a tool reports findings, that is part of your verdict — do not treat Layer 1 passing
   as sufficient when Layer 2 tooling exists and wasn't clean.

## Layer 3 — semantic and repo-boundary review

Read `references/rails-review.md` for the twelve failure categories no AST cop can prove: process-local
singleton/global state, unbounded session/cookie/cache state, fake/stub contract drift, stored-but-unused
state and dead Stimulus/Turbo wiring, CI/security guardrail weakening, external side effects inside a
transaction, nested-resource/tenant scoping, background-job timing and idempotency, cache-key dimensions,
schema/migration safety, secrets and deploy completeness, and duplicated logic. Read only the categories
relevant to what the diff actually touches — you rarely need all twelve for one PR.

For every review:

1. **Read the full diff, not just changed lines.** For each change, find its read path (who consumes
   this write?), its concurrency exposure (multi-worker, multi-request), and its failure mode (what
   happens if the external call, transaction, or job fails partway?).
2. **Write or run a focused behavioral test per suspected hazard**, not a broad regression sweep. Match
   the test to the failure mode in `rails-review.md` — e.g., for stored-but-unreplayed state, perform the
   action twice and assert the *second* request sees the first's state; for a transaction/external-effect
   hazard, force a rollback and assert the side effect didn't fire. A test that only exercises the happy
   path once proves nothing about these categories.
3. **Give an evidence-backed verdict.** State what you ran (Layers 1 and 2 commands, their results) and
   what you inspected or tested in Layer 3, with concrete file:line references — not "looks fine" or
   "should be safe."
4. **Disclose what you did not check.** List: any Layer 2 tool that was absent and not run, any
   `rails-review.md` category you judged out of scope for this diff and why, and any hazard you noticed
   but couldn't verify (e.g., "multi-worker behavior is unverified — the test suite runs single-process").
   A verdict without this disclosure is incomplete; the human reviewer needs to know the residual risk,
   not just the parts that were checked.

## Notes

- The six cops are the reliable default, not a full Rails-slop catalog — see this repo's `README.md` and
  `docs/research.md` for why the cop count stays small instead of absorbing coverage `rubocop-rails` and
  Brakeman already provide.
- Layer 3's categories are labeled in `rails-review.md` as either evidenced directly by the [LLM Coding
  Benchmark's success report](https://github.com/akitaonrails/llm-coding-benchmark/blob/master/docs/success_report.md)
  or as general Rails hazards from framework/tooling documentation — that benchmark is one report on one
  application shape, not proof the list is exhaustive.
