---
name: install-anti-slop-ror
description: Two independent uses — install/vendor the anti-slop-ror StandardRB/RuboCop plugin (six AST cops for Ruby on Rails) into a Rails repo, or audit/review AI- or agent-generated Ruby/Rails diffs for slop by running the target repo's own existing Rails safety tools (StandardRB, rubocop-rails/standard-rails, Brakeman, tests) read-only and doing a semantic review pass for boundaries no AST cop can prove — reviewing does not require installing the plugin first. Use when (1) installing, updating, or vendoring the anti-slop-ror plugin into a Rails repo, (2) reviewing, auditing, or approving an AI agent's Ruby/Rails changes before merge, (3) checking whether a Rails diff introduced silent state loss, untested integration boundaries, weakened CI/security guardrails, or other slop the AST cops cannot catch, or (4) deciding whether a Rails PR is safe to ship.
---

# Anti-slop Rails workflow

Two modes. Pick the one the user actually asked for — do not assume one implies the other, and if the
request is ambiguous, ask rather than defaulting to installing.

- **Review/audit mode** — reviewing, auditing, or approving a Rails diff/PR, or deciding if it's safe to
  ship. Read-only against the target repo: inspect existing configuration and run existing commands only.
  Never run the installer, never add or edit a dependency, `.standard.yml`/`.rubocop.yml` entry, or any
  other file in the target repo. If the anti-slop-ror cops aren't already installed there, report that as
  a coverage gap in your verdict — do not install them to close it.
- **Install/setup mode** — installing, vendoring, updating, or configuring the anti-slop-ror plugin, or
  the user explicitly asked for both. May run the installer and make the requested integration changes.

## Install/setup mode — Layer 1

The six cops are AST-local, no-autocorrect, and catch narrow, high-confidence anti-patterns: silent
rescue, request-driven dynamic dispatch, unsafe request-controlled redirects, unbounded strong
parameters, interpolated SQL, and swallowed `StatementInvalid` inside a transaction.

1. Confirm the target already uses StandardRB. If it does not, report that prerequisite; do not add or
   change dependencies unless the user requested that broader setup.
2. Resolve `<skill-dir>` as the directory containing this `SKILL.md`, then run
   `ruby <skill-dir>/scripts/install.rb TARGET`. This vendors the bundled source without requiring the
   anti-slop-ror repository, a published gem, or network access. It refuses to overwrite an existing
   `TARGET/tools/anti_slop_ror`; pass `--force` only when the user explicitly intends to replace that
   snapshot.
3. Add the exact `.standard.yml` plugin block printed by the installer; do not hand-write a different
   require path.
4. Run the blocking check: `bundle exec standardrb --raise-cop-error`.
5. Every finding needs a human decision — there is no autocorrect. Do not suppress a finding without
   understanding why the cop fired; inspect the installed cop and the target code around the offense.

Gem publication is optional and is not part of the default install path. Use a gem-based installation
only when the user explicitly requests it and the requested gem/version is verified available.

Installing does not substitute for a review: it only adds these six cops to the target's own lint run.
If the user also wants their diff reviewed, continue into review/audit mode below.

## Review/audit mode

Everything here runs read-only against the target repo: run its existing commands, inspect its existing
configuration, do not add tooling or config to close a gap you find.

### Layer 2 — existing-tool coverage: check before you trust it

A tool being present, a command being runnable, or a clean/passing run does **not** by itself prove a
specific named cop was enabled and applicable to this target — check the *effective* configuration, not
just presence.

1. Inspect the target's `Gemfile`/`Gemfile.lock` (or `bundle list`) for: `standard`/`rubocop`,
   `standard-rails`/`rubocop-rails`, `brakeman`, and a test framework (RSpec/Minitest). Separately check
   whether `.standard.yml`/`.rubocop.yml` already has the `anti_slop_ror` plugin block — if not, that is
   itself a Layer-1 coverage gap to report, not something to add here.
2. For each tool present, run its existing blocking invocation as already configured — do not add flags
   or config it doesn't already have: `bundle exec standardrb --raise-cop-error` (or `rubocop`),
   `bundle exec brakeman` (or the project's documented invocation), the project's test command.
3. Before crediting a specific `rubocop-rails` cop's coverage in your verdict, check whether it's actually
   enabled and applicable — inspect the merged `.rubocop.yml`/`.standard.yml` (or
   `bundle exec rubocop --show-cops Rails/<Cop>`) and the target's Rails version. In particular:
   - `Rails/SaveBang` and `Rails/SkipsModelValidations` are disabled (`Enabled: false`) by the
     `standard-rails` baseline even though `rubocop-rails` ships both — a clean StandardRB run under
     `standard-rails` proves nothing about either unless the target re-enabled them.
   - `Rails/TransactionExitStatement` is a "pending" cop (off by default in plain `rubocop-rails` unless
     `NewCops: enable`, though `standard-rails` does enable it); even when enabled, the cop is a no-op on
     Rails >= 7.2 and version-config-gated on Rails 7.1 — check the target's Rails version before
     crediting it.
   - `Rails/UniqueValidationWithoutIndex` requires `db/schema.rb` to exist and only scans
     `app/models/**/*.rb` by default.
   Only credit a named cop's coverage if you've confirmed it's enabled and applicable to this target;
   otherwise report it as missing, disabled, or unverified — never as passing.
4. State every gap plainly in your verdict: absent tools, absent anti-slop-ror install, and disabled or
   unverified named cops. Example: "Rails/SaveBang is disabled under this repo's standard-rails baseline;
   unchecked `save`/`update` calls in this diff were not caught by a cop." If tests fail or a tool reports
   findings, that's part of your verdict too.

### Layer 3 — semantic and repo-boundary review

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
   hazard, force a rollback and assert the side effect didn't fire. A rollback test proves the effect is
   rollback-safe, not that it's durable or exactly-once — see `rails-review.md` §6 for what delivery
   guarantees still need separate evidence. A test that only exercises the happy path once proves nothing
   about these categories.
3. **Give an evidence-backed verdict.** State what you ran (Layer 2 commands and results, including which
   named cops you confirmed enabled vs. disabled/unverified) and what you inspected or tested in Layer 3,
   with concrete file:line references — not "looks fine" or "should be safe."
4. **Disclose what you did not check.** List: any Layer 1/2 tool or cop that was absent, disabled, or
   unverified, any `rails-review.md` category you judged out of scope for this diff and why, and any
   hazard you noticed but couldn't verify (e.g., "multi-worker behavior is unverified — the test suite
   runs single-process"). A verdict without this disclosure is incomplete; the human reviewer needs to
   know the residual risk, not just the parts that were checked.

## Notes

- The six cops are the reliable default, not a full Rails-slop catalog. They do not duplicate checks
  `rubocop-rails` and Brakeman can provide when those checks are actually enabled for the target (see
  Layer 2 above — presence of a gem is not the same as active coverage).
- Layer 3's categories are labeled in `rails-review.md` as either evidenced directly by the [LLM Coding
  Benchmark's success report](https://github.com/akitaonrails/llm-coding-benchmark/blob/master/docs/success_report.md)
  or as general Rails hazards from framework/tooling documentation — that benchmark is one report on one
  application shape, not proof the list is exhaustive.
