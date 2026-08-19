# Rails semantic review reference

Twelve failure categories an AST cop cannot prove. For each: the bad shape, how it fails silently in
production, what to inspect in the diff, what proof establishes safety, and whether any part of it is
statically lintable today. Read the category that matches what the diff touches; you rarely need all twelve.

**Evidence labels.** *Benchmark-evidenced* categories are named failure modes from the [LLM Coding
Benchmark's success report](https://github.com/akitaonrails/llm-coding-benchmark/blob/master/docs/success_report.md)
(40 models building an identical Rails/Hotwire/RubyLLM chat app, graded on a holistic rubric). That
report is one benchmark on one application shape — treat it as evidence real agents produce these bugs,
not proof that this list is exhaustive or that any category is Rails-universal. *General Rails hazard*
categories come from Rails' own guides, RuboCop Rails' cop inventory, or Brakeman's documented warning
types — these are standing framework guidance, not benchmark findings.

## Contents

1. [Process-local singleton / class-variable / mutable-global state](#1-process-local-singleton--class-variable--mutable-global-state)
2. [Unbounded session, cookie, cache, or history state](#2-unbounded-session-cookie-cache-or-history-state)
3. [Fake/stub contract drift and untested integration boundaries](#3-fakestub-contract-drift-and-untested-integration-boundaries)
4. [Stored state never replayed; dead Stimulus/Turbo wiring](#4-stored-state-never-replayed-dead-stimulusturbo-wiring)
5. [CI and security guardrail weakening](#5-ci-and-security-guardrail-weakening)
6. [External side effects inside a DB transaction](#6-external-side-effects-inside-a-db-transaction)
7. [Nested-resource / tenant ownership scoping](#7-nested-resource--tenant-ownership-scoping)
8. [Background job enqueue timing, retries, and argument durability](#8-background-job-enqueue-timing-retries-and-argument-durability)
9. [Cache-key dimensions and invalidation](#9-cache-key-dimensions-and-invalidation)
10. [Schema constraints and migration/deploy safety](#10-schema-constraints-and-migrationdeploy-safety)
11. [Secrets, production dependency groups, Docker/deployment completeness](#11-secrets-production-dependency-groups-dockerdeployment-completeness)
12. [Duplicated/reimplemented logic instead of reuse](#12-duplicatedreimplemented-logic-instead-of-reuse)

---

## 1. Process-local singleton / class-variable / mutable-global state

**Evidence:** benchmark-evidenced. The report scores "Persistence/multi-turn" separately and calls out a
`@@all`-style class-variable store as "process-local, memory leak, not multi-worker safe," and a
`Chat::ConversationStore` singleton as "thread-safe and capped, but history dies on restart and breaks
under multi-worker Puma."

- **Bad shape:** `@@` class variables, `class << self; @store ||= {}; end` memoized hashes, `Rails.cache`
  used as the *only* store for data that must survive a deploy, or any plain Ruby object held in a
  constant/class ivar that accumulates state across requests.
- **Silent failure:** Works perfectly in a single-process `rails server` dev session and in the request
  spec that runs in-process. In production with Puma workers > 1, half of requests miss the state
  entirely; on every deploy or restart, all of it is gone. No exception, no log line — just data that
  "randomly" isn't there.
- **What to inspect:** Any new class variable, class-level memoized ivar, or constant holding mutable
  data. Ask where it's written from a request and whether that same process serves the next read.
- **What proves safety:** A test or explicit code comment showing the store is either (a) request/session
  scoped and rebuilt each time, or (b) backed by the database or a shared cache with a documented TTL.
  Multi-process behavior can't be proven by an in-process spec — call this out as unverified if the test
  suite only runs single-process.
- **Statically lintable:** No general cop exists for "is this global mutable and multi-worker-unsafe" —
  it requires knowing the deployment topology. Flag it in review, don't expect a linter to catch it.

## 2. Unbounded session, cookie, cache, or history state

**Evidence:** benchmark-evidenced. The report names a "4KB cookie overflow: long chat histories exceed
session-cookie size limit" as a concrete failure, and notes Tier A (ship-as-is) submissions were exactly
the ones using "session cookie with cap or `Rails.cache` + TTL + size limit."

- **Bad shape:** Appending to a `session[:history]` array or hash with no cap, storing full request/response
  bodies, uploaded file content, or growing arrays in the cookie-backed session store.
- **Silent failure:** Works in dev with a short conversation. In production, once serialized session data
  exceeds ~4KB (cookie store) it either raises `ActionDispatch::Cookies::CookieOverflow` or silently
  truncates depending on store, and users lose history mid-session with no error surfaced to them.
- **What to inspect:** Any `session[...] <<` or `session[...] +=` pattern; any cache write without
  `expires_in`; any user-facing "keep everything" state (chat history, undo stack, notification feed).
- **What proves safety:** A test that grows the state past a realistic bound and asserts either an
  explicit cap/eviction or a store that isn't cookie-backed. See the [Rails caching
  guide](https://guides.rubyonrails.org/caching_with_rails.html) for `Rails.cache` with `expires_in`.
- **Statically lintable:** No. Bound-checking session/cache growth requires knowing the store backend and
  realistic data volume, both outside the AST.

## 3. Fake/stub contract drift and untested integration boundaries

**Evidence:** benchmark-evidenced, and the report's blunt line on this is the sharpest quote in the whole
document: *"A test suite that doesn't exercise the LLM code path cannot catch bugs in that path, no
matter how many test methods you count."* ~70% of the scored models used the target API correctly, ~30%
hallucinated or bypassed it — divergence that a suite mocking the wrong contract cannot catch.

- **Bad shape:** `allow(SomeClient).to receive(:call).and_return(...)` where the return shape was invented
  by the agent rather than copied from the real client; a fake/stub class hand-rolled to "look like" a
  gem's interface instead of a verified double; tests that pass because the mock's contract silently
  drifted from the real one after an interface change.
- **Silent failure:** The suite is green. In production the real client raises `NoMethodError`, returns a
  different shape, or the call never fires the way the stub assumed — and nothing in CI would have caught
  it because CI never touched the real boundary.
- **What to inspect:** Every new or changed stub/mock in the diff. Does it match the *current* method
  signature and return shape of the real collaborator? Is there `verify_partial_doubles` (RSpec) or
  equivalent enabled, and does the stub target actually exist?
- **What proves safety:** Either an integration test that hits the real dependency (or a recorded
  fixture/VCR cassette from a real call), or an explicit note that the boundary is untested and why.
  Contract/interface tests that fail if the real API changes are strong evidence; hand-verify the mock
  against the gem/API source if no such test exists.
- **Statically lintable:** No. Detecting stub/reality drift requires comparing test doubles against a
  live interface, not syntax.

## 4. Stored state never replayed; dead Stimulus/Turbo wiring

**Evidence:** benchmark-evidenced. Named failures: a "double-send bug" where "user message appended
before service replays history" so it "reaches LLM twice"; "lost multi-turn: fresh RubyLLM chat per
request, history stored but never replayed"; and "dead Stimulus code: `data-controller` attributes inert
(no JS import/Application.start)."

- **Bad shape:** Data written to a model/column/store that no read path ever consumes; a `data-controller`
  or `data-action` attribute added to a view with no matching Stimulus controller registered/imported, or
  a Turbo Stream broadcast with no subscriber; state reconstructed fresh on each request instead of loaded
  from where it was persisted.
- **Silent failure:** The write succeeds, the page renders, nothing errors — the feature simply doesn't do
  anything. Discovered only by manually exercising the exact user flow twice in a row.
- **What to inspect:** For every new persisted field/record, find the read path. For every new
  `data-controller="x"`, confirm `x_controller.js` is registered in the importmap/controllers index. For
  every `broadcast_*`, confirm a `<turbo-stream-source>` or channel subscription exists.
- **What proves safety:** A behavioral test that performs the action twice (or reloads) and asserts the
  *previous* state is visible/used the second time — not just that the write succeeded.
- **Statically lintable:** Partial. Missing Stimulus controller registration is checkable by cross-referencing
  the controllers manifest against `data-controller` values, but no cop in this project or RuboCop Rails
  does that; it is a review-time check, not a shipped cop.

## 5. CI and security guardrail weakening

**Evidence:** mixed. Benchmark-evidenced: submissions were penalized for "committing `.env` with real
`OPENROUTER_API_KEY`" and for "missing bundle-audit in CI tooling." The CSRF/`protect_from_forgery`
mechanics below are general Rails hazard, from the [Rails security
guide](https://guides.rubyonrails.org/security.html) and [GitHub's agent-PR review
guidance](https://github.blog/ai-and-ml/generative-ai/agent-pull-requests-are-everywhere-heres-how-to-review-them/),
not from this benchmark.

- **Bad shape:** A diff that adds `skip_forgery_protection`, downgrades `protect_from_forgery with:
  :exception` to `:null_session`, adds `|| true` after a CI command, removes/skips/renames a test instead
  of fixing it, drops a security-scanning step (Brakeman, bundle-audit) from CI, or narrows a workflow's
  trigger so it no longer runs on the branch that matters.
- **Silent failure:** CI stays green because the check that would have caught the regression no longer
  runs. Nobody notices until an incident.
- **What to inspect:** Diff every CI/workflow file change and every `protect_from_forgery`/
  `skip_before_action`/`skip_forgery_protection` line. GitHub's guidance: "Verify coverage thresholds
  haven't changed... confirm no tests were removed, skipped, or renamed... check that CI still runs on
  forks and pull requests." Treat any of these as a stop-the-review finding, not a nit.
- **What proves safety:** A stated, reviewed reason for the exception. CSRF-exempt JSON/webhook endpoints
  are a legitimate, common pattern — Rails itself skips CSRF for API-only apps — but that requires
  *evidence* in the diff (a comment, a linked ticket, or the endpoint genuinely being a signature-verified
  webhook), not silent removal. Absent that evidence, treat weakening as a regression.
- **Statically lintable:** Partial. `Lint/*` and Brakeman's `Cross-Site Request Forgery (CSRF)` warning
  type (see [Brakeman warning types](https://brakemanscanner.org/docs/warning_types/)) catch some
  disablement patterns, but a removed CI step or skipped test is invisible to any linter run *inside* that
  same CI — it has to be caught by diffing the workflow file itself.

## 6. External side effects inside a DB transaction

**Evidence:** general Rails hazard, from the [Rails transaction callbacks
guide](https://guides.rubyonrails.org/active_record_callbacks.html#transaction-callbacks). Not a named
finding in the benchmark report (which tests a single chat app, not this pattern), but a standing Rails
footgun.

- **Bad shape:** An email send, external API call (payment, webhook, third-party notification), or job
  enqueue placed directly inside a `transaction do ... end` block or inside a regular `after_save`/
  `after_create` callback that runs before commit.
- **Silent failure:** Two failure directions. If the transaction later rolls back, the external side
  effect already fired — a customer gets charged or emailed for a record that doesn't exist. If the side
  effect raises, Rails' guide is explicit that "the exception will bubble up and any remaining
  `after_commit` or `after_rollback` methods will not be executed" when misplaced, and pre-commit
  exceptions abort the save. Both directions produce state that's inconsistent between the DB and the
  outside world with no automatic reconciliation. Moving the call to `after_commit` fixes *this specific*
  rollback-consistency problem — it does not, by itself, make the side effect durable or exactly-once (see
  next paragraph).
- **`after_commit` is not a delivery guarantee.** It only separates the side effect from rollback; it adds
  no durability of its own. The Rails guide itself notes that "during `after_commit` the data was already
  persisted to the database, and thus any exception won't roll anything back anymore" — which cuts both
  ways: an exception *inside* the `after_commit` callback, or the process crashing between the commit and
  the callback running, means the row exists but the external effect silently never fires, with nothing to
  retry it. For delivery-critical effects (payments, required emails, webhooks), `after_commit` alone is
  not proof of safety.
- **What to inspect:** Any `transaction do` block or `after_save`/`after_create`/`after_update` callback
  that calls an external API, sends mail, or performs a non-DB write. It belongs in `after_commit` instead
  — the guide notes these callbacks exist because models "need to interact with external systems that are
  not part of the database transaction." For anything delivery-critical, check further: is the effect
  itself durable (a durable outbox row, or a queued job written via `enqueue_after_transaction_commit` —
  see [§8](#8-background-job-enqueue-timing-retries-and-argument-durability) — rather than a synchronous
  call inside the callback), does it have a retry policy, and is it idempotent/deduplicated so a retry
  can't double-fire it?
- **What proves safety:** For rollback-consistency: the side effect is in `after_commit` (or triggered
  after the transaction block exits successfully), and a test that forces a rollback mid-transaction and
  asserts the external effect did *not* fire. That test proves rollback-safety only — treat it as
  incomplete evidence, not a full verdict. For delivery-critical effects, additionally require evidence of
  a durable outbox or durable post-commit job, a retry policy, and an idempotency/deduplication key —
  without that evidence, disclose durability as unverified rather than asserting the effect is safe.
- **Statically lintable:** No cop in this project or RuboCop Rails flags "external call inside
  transaction" generically — it requires knowing which calls are external, which isn't visible to AST-only
  analysis. RuboCop Rails ships the related-but-distinct `Rails/TransactionExitStatement` for
  `return`/`break`/`throw` inside a transaction, but only when it's actually enabled and applicable — see
  [§10](#10-schema-constraints-and-migrationdeploy-safety) for why presence of the gem isn't enough.

## 7. Nested-resource / tenant ownership scoping

**Evidence:** general Rails hazard (classic IDOR/authorization pattern; not a benchmark-report finding —
the benchmark's single-user chat app doesn't exercise multi-tenant nesting).

- **Bad shape:** `Comment.find(params[:id])` or `current_user.posts.find(params[:id])` skipped in favor of
  a bare top-level lookup inside a nested route (`/posts/:post_id/comments/:id`), so the `post_id` in the
  URL is never checked against the loaded comment's actual parent.
- **Silent failure:** Every "happy path" test that uses IDs the current user actually owns passes. Any
  user who edits the URL's ID to someone else's record gets it anyway — a straightforward IDOR that
  produces no error, just wrong (or leaked) data.
- **What to inspect:** Every nested-route controller action: does the lookup scope through the parent
  association / `current_user` / `current_account`, or does it `find` from the model class directly?
- **What proves safety:** A test written from the *attacker's* perspective — authenticated as user/tenant
  A, request a resource ID belonging to user/tenant B, assert 404/403, not 200.
- **Statically lintable:** No. Whether a `find` is properly scoped depends on association structure and
  authorization design that RuboCop's AST view can't reconstruct.

## 8. Background job enqueue timing, retries, and argument durability

**Evidence:** general Rails hazard, from the [Rails Active Job
guide](https://guides.rubyonrails.org/active_job_basics.html). Not a benchmark-report finding.

- **Bad shape:** `SomeJob.perform_later(record)` called inside a still-open transaction without
  `enqueue_after_transaction_commit`, a job with no `retry_on`/`discard_on` for a call that can transiently
  fail, or a job argument that's a plain hash/array snapshot of a record instead of the record itself.
- **Silent failure:** If the queue adapter processes faster than the enclosing transaction commits (common
  with a fast in-memory or same-process adapter), the job runs before the row it needs exists, and fails
  or reads stale data — intermittently, in a way that doesn't reproduce locally. If the passed record is
  deleted before the job runs, Active Job raises `ActiveJob::DeserializationError` — the guide is explicit
  about this — and an unhandled version of that is a silent job-queue failure. A snapshotted-hash argument
  goes stale silently instead of erroring at all.
- **What to inspect:** Every `perform_later` call: is it after the transaction that creates its data
  commits, or guarded by `enqueue_after_transaction_commit`? Does the job pass live Active Record objects
  (which serialize via GlobalID) rather than manually extracted attribute hashes? Is there `retry_on` for
  plausible transient failures?
- **What proves safety:** A test that runs the enqueued job with `perform_enqueued_jobs`/inline adapter
  after the surrounding transaction commits, and — for record arguments — a test asserting the job
  degrades correctly (via `retry_on`/`discard_on`) when the referenced record no longer exists.
- **Statically lintable:** No general cop checks transaction/enqueue ordering or argument durability; it
  requires tracing the transaction boundary at runtime.

## 9. Cache-key dimensions and invalidation

**Evidence:** general Rails hazard, from the [Rails caching
guide](https://guides.rubyonrails.org/caching_with_rails.html). Not a benchmark-report finding (the
report's cache mentions are about session persistence, category 2 above, not key dimensioning).

- **Bad shape:** A low-level `Rails.cache.fetch(key)` whose key omits a dimension the cached value actually
  depends on — locale, current user/tenant, a feature flag, or a template version — or a fragment cache
  key built from a record without `cache_key_with_version` (i.e., missing `updated_at`), so it never
  changes when the record does.
- **Silent failure:** The first user/locale/variant to populate the cache "wins," and every subsequent
  request serves their cached value to everyone else until the TTL expires. No error; just wrong (and
  sometimes cross-user-leaked) content.
- **What to inspect:** Every `Rails.cache.fetch`/`write` and every `cache do...end` view block: does the
  key include every value the block's output actually depends on? Rails' own key includes "the model's
  class name, `id`, and `updated_at`" by default via `cache_key_with_version` — a custom key that drops
  back to just `id` loses that invalidation for free.
- **What proves safety:** A test that changes one of the suspected dimensions (locale, user, the record's
  `updated_at`) and asserts the cached output changes too, not just that caching happened.
- **Statically lintable:** No. Judging whether a key covers all the dimensions the cached block depends on
  requires understanding the block's data dependencies, not just its syntax.

## 10. Schema constraints and migration/deploy safety

**Evidence:** general Rails hazard, from the [Rails validations uniqueness
warning](https://guides.rubyonrails.org/active_record_validations.html#uniqueness) and RuboCop Rails' cop
inventory. Not a benchmark-report finding.

- **Bad shape:** `validates :email, uniqueness: true` with no corresponding `add_index ... unique: true`
  migration; `update_all`/`update_column`/`save(validate: false)` used where validations matter; a
  migration that adds a `NOT NULL` column without a default to a populated table, or that isn't reversible.
- **Silent failure:** The uniqueness validation passes in every single-request test. Under concurrent
  writes in production, Rails' own guide states plainly: "This validation does not create a uniqueness
  constraint in the database, so a scenario can occur whereby two different database connections create
  two records with the same value." Duplicate rows appear with no error anywhere in the stack.
- **What to inspect:** Every new `uniqueness: true` validation — is there a matching unique index in the
  same or a prior migration? Every `update_all`/`update_column`/`update_attribute`/`save(validate: false)`
  — is skipping validation intentional and safe here?
- **What proves safety:** The schema (`db/schema.rb`) shows a matching unique index, or a test that races
  two concurrent inserts and asserts the database (not just the validation) rejects the duplicate.
- **Statically lintable:** Partial, and only when the specific cop is actually enabled for the target —
  presence of `rubocop-rails`/`standard-rails` in the `Gemfile` does not by itself mean these are active.
  `rubocop-rails` ships `Rails/UniqueValidationWithoutIndex` (flags a `uniqueness:` validation with no
  matching schema index; needs `db/schema.rb` to exist, and only scans `app/models/**/*.rb` by default),
  `Rails/SkipsModelValidations` (flags `update_column`, `update_attribute`, `update_all`,
  `save(validate: false)`, and similar), and `Rails/SaveBang` (flags `save`/`update`/`create` calls whose
  failure return value is silently ignored) — but the `standard-rails` baseline this project targets
  explicitly disables both `Rails/SaveBang` and `Rails/SkipsModelValidations` (`Enabled: false`). Before
  crediting either in a review verdict, check the target's *effective* `.rubocop.yml`/`.standard.yml`, not
  just which gems are installed — see [SKILL.md](../SKILL.md)'s Layer 2 for how. If a cop is disabled or
  its Rails-version precondition isn't met, report the gap as unverified, not as passing coverage — see
  the [RuboCop Rails cop inventory](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html).

## 11. Secrets, production dependency groups, Docker/deployment completeness

**Evidence:** benchmark-evidenced directly. The report's "Deliverable completeness" (25% of the score) and
"Production readiness" (5%) dimensions penalize exactly this: committing `.env` with a real API key,
"dev-mode Dockerfiles" that use `RAILS_ENV=development`, run as root, and start with `./bin/dev` as an
"unshippable" entrypoint, and missing preflight checks for required environment variables.

- **Bad shape:** A `.env` file with real credentials committed to the repo; a `Dockerfile`/`docker-compose`
  that runs as root or in development mode; a gem needed only for the app's actual runtime path added to
  the wrong Gemfile group (or a required gem never added at all, discovered only at boot); no check for a
  required environment variable before the code that needs it runs.
- **Silent failure:** `docker build && docker run` "works" in the sense that it boots, but ships a
  dev-mode, root-user container, or a container that crashes immediately in production because
  `ENV.fetch("REQUIRED_KEY")` was assumed present with no local preflight message explaining what's
  missing, or crashes on the first request that hits a code path needing a gem that's only in `:development`.
- **What to inspect:** Any new/changed `Dockerfile`, `docker-compose.yml`, `.env*` file, or `Gemfile`
  group. Does the container run non-root, `RAILS_ENV=production`, with a production-appropriate
  entrypoint? Is every credential referenced via `ENV`/Rails credentials rather than hardcoded? Does app
  boot fail loudly (not silently) if a required var is absent?
- **What proves safety:** `docker build` from a clean checkout followed by actually running the container
  and exercising a real request path (not just "it started"); grep for committed secrets before merge;
  confirm no gem needed at runtime lives only in a non-production Gemfile group.
- **Statically lintable:** Partial. Brakeman's documented categories don't include Docker/deploy
  completeness, but do cover related secret/credential and `SSL Verification Bypass` classes (see
  [Brakeman warning types](https://brakemanscanner.org/docs/warning_types/)); most of this category is a
  manual build-and-run check, not a lint pass.

## 12. Duplicated/reimplemented logic instead of reuse

**Evidence:** general LLM-agent hazard — not Rails-specific and not from the akitaonrails benchmark
report. Grounded in the [*More Code, Less Reuse*](https://arxiv.org/abs/2601.21276) research on
AI-generated pull requests and in [GitHub's agent-PR review
guidance](https://github.blog/ai-and-ml/generative-ai/agent-pull-requests-are-everywhere-heres-how-to-review-them/).

- **Bad shape:** A new private helper, service object, or inline block that re-derives logic an existing
  model method, concern, or utility already provides — usually because the agent didn't search for the
  existing implementation before writing a new one.
- **Silent failure:** Nothing crashes. The duplicate quietly diverges from the original over time as one
  copy gets bugfixed and the other doesn't — the paper's finding is that reviewers rate this code as
  "neutral or positive" specifically because it looks locally fine, which is why it survives review and
  becomes "silent accumulation of technical debt." GitHub's guidance adds the compounding risk directly:
  "the cost of leaving duplicated logic is that agents will find it as prior art and replicate it further."
- **What to inspect:** For every new method/class in the diff, search the codebase for an existing
  equivalent before approving. This is a review action, not something to defer to CI.
- **What proves safety:** No test proves absence of duplication — it's established by a deliberate search
  (grep/semantic search for similar method names or behavior) during review, documented as done.
- **Statically lintable:** No. Detecting semantic duplication (not textual clones) is outside what
  RuboCop's per-file AST analysis does.

## Primary sources

- [LLM Coding Benchmark success report (canonical)](https://github.com/akitaonrails/llm-coding-benchmark/blob/master/docs/success_report.md)
- [Rails caching guide](https://guides.rubyonrails.org/caching_with_rails.html)
- [Rails transaction callbacks](https://guides.rubyonrails.org/active_record_callbacks.html#transaction-callbacks)
- [Rails validations — uniqueness](https://guides.rubyonrails.org/active_record_validations.html#uniqueness)
- [Rails security guide](https://guides.rubyonrails.org/security.html)
- [Rails Active Job basics](https://guides.rubyonrails.org/active_job_basics.html)
- [RuboCop Rails cop inventory](https://docs.rubocop.org/rubocop-rails/latest/cops_rails.html)
- [Brakeman warning types](https://brakemanscanner.org/docs/warning_types/)
- [GitHub: how to review agent pull requests](https://github.blog/ai-and-ml/generative-ai/agent-pull-requests-are-everywhere-heres-how-to-review-them/)
- [More Code, Less Reuse](https://arxiv.org/abs/2601.21276)
