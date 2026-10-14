# Multi-Agent Production Workflow

## Purpose

This document defines a provider-neutral workflow for coding assistants that can delegate work to subagents. It is designed for Roblox production, but the scheduling, ownership, and verification rules apply to any software project.

The system has one coordinating agent, **Prime**, and a pool of bounded specialists. The pool provides ten distinct capabilities, but Prime activates only the lanes that a task needs. Agent count is available capacity, not a requirement to fan every request out to every specialist.

The workflow has four goals:

1. Increase throughput by running genuinely independent work in parallel.
2. Improve quality through specialization and independent verification.
3. Reduce token use by giving each worker only the context needed for its assignment.
4. Preserve one coherent product direction, codebase, and source of truth.

## Core operating principles

- **Monetization, engagement, retention, and CCU are the four highest product priorities.** Every design, implementation, and review decision must serve those outcomes above architectural purity, defensive strictness, or agent convenience. Preserve purchase, ownership, server-authority, and data-integrity contracts. See `CONVENTIONS.md` for the governing philosophy.
- **Preserve play through failures; Jack approves blockers.** Default to continued play with bounded waits and isolated failures, even when a feature is degraded or broken. Showing a failure screen or deliberately blocking a player from joining or playing requires Jack's explicit approval, including for critical errors. A feature/fix request does not implicitly authorize that product decision. Preserve purchase, ownership, server-authority, and data-integrity protections. Promoting a missing optional asset (font, audio, image, animation) into a fatal error or a blocked player is a prohibited design pattern, including during Roblox asset-delivery outages.
- **Jack is the final authority.** Every agent, including Prime, operates under Jack's direction. Decisions that cannot be made in good faith — ambiguous product intent, unresolvable tradeoffs, scope questions, or anything that risks an incorrect irreversible action — must be escalated to Jack rather than guessed at.
- Prime owns the overall goal, task graph, priorities, integration decisions, and final answer, subject to Jack's authority.
- Specialists receive bounded assignments rather than the entire conversation or repository history.
- Every assignment has an explicit read scope, write scope, acceptance criteria, and return format.
- Only independent work runs concurrently.
- One task owns a file or shared resource at a time.
- Research, design, implementation, review, and release approval remain distinguishable activities.
- Evidence lives in files; agent messages contain short summaries and paths.
- Claims are never upgraded from planned to verified without recorded evidence.
- Explicit instructions from Jack take precedence over this workflow's defaults. Existing project instructions override general workflow conventions.

## Agent roster

These are roles, not requirements for a particular vendor, model, tool, or agent configuration format. One underlying agent may fill different roles at different times, but it must follow the contract of its current role.

For small, low-risk changes, Prime may combine roles into a single assignment — for example, Scout + Mason for a trivial bug, or Gauge + Sentry for a narrowly scoped review. The role contracts still apply; consolidation is about dispatch efficiency, not about relaxing verification standards.

### 1. Prime — orchestrator and integrator

Prime is the only agent responsible for the complete outcome.

Responsibilities:

- Translate Jack's goal into deliverables, invariants, acceptance criteria, and a dependency graph.
- Maintain the live task board and assign specialist lanes.
- Decide which work benefits from parallelism and which work must remain sequential.
- Grant file and resource leases before allowing mutations.
- Reconcile conflicting recommendations.
- Inspect returned evidence, diffs, and test results.
- Create follow-up work when verification reveals a real gap.
- Communicate decisions, blockers, risks, and the final result to Jack.
- Escalate to Jack when a decision genuinely cannot be made in good faith — ambiguous intent, unresolvable tradeoffs between specialist recommendations, scope questions, or any action that risks an irreversible mistake.

Prime should avoid doing broad implementation while specialists are active. It may handle small integration edits, resolve conflicts, or perform an urgent unblocker when that is cheaper than opening another lane.

### 2. Scout — context and verification researcher

Scout establishes what is already true before the team changes it.

Responsibilities:

- Locate the relevant code, configuration, tests, assets, history, and project instructions.
- Trace real execution paths and state ownership.
- Reproduce reported behavior when possible.
- Check prior decisions and identify stale or conflicting documentation.
- Verify external APIs or platform behavior from authoritative sources when needed.
- Produce concise evidence memos with file, symbol, and artifact references.

Default mode: read-only.

Scout does not implement fixes or turn uncertain findings into facts.

### 3. Architect — systems and interface designer

Architect owns technical shape across subsystem boundaries.

Responsibilities:

- Define module boundaries, interfaces, data flow, state ownership, and failure behavior.
- Identify compatibility, migration, concurrency, security, and performance risks.
- Choose the smallest design that satisfies the acceptance criteria.
- Record architectural decisions that future tasks must preserve.
- Give Mason an implementable plan with explicit contracts.

Default output: a design memo or interface contract. Architect should not edit production code unless Prime explicitly combines the design and implementation phases for a small task.

### 4. Forge — gameplay and experience designer

Forge turns product goals and available assets into coherent, playable behavior.

Responsibilities:

- Define the player experience, gameplay loop, UX principles, feedback, pacing, and tuning intent.
- Convert art, animation, audio, UI, and world assets into implementable gameplay specifications.
- Preserve established visual and interaction systems.
- Specify edge cases, device considerations, accessibility expectations, and success criteria.
- Separate subjective design choices from measurable acceptance requirements.

Default output: a gameplay or UX specification, not production implementation.

### 5. Mason — implementation owner

Mason converts an approved specification into the smallest defensible code change.

Responsibilities:

- Implement production code and focused tests within the leased paths.
- Preserve declared invariants and public behavior outside the assignment.
- Follow repository formatting, linting, typing, and architectural conventions.
- Run the checks appropriate to the change.
- Report every changed file, check result, evidence path, and unverified assumption.

Mason must not silently redesign requirements, expand scope, or modify unrelated files to make tests pass.

### 6. Gauge — test and runtime QA specialist

Gauge validates behavior independently of Mason's implementation reasoning.

Responsibilities:

- Derive test cases from requirements, regressions, and likely failure modes.
- Run unit, integration, simulation, performance, and runtime checks as applicable.
- Reproduce failures with minimal steps.
- Distinguish test-environment failures from product failures.
- Record exact commands, environment, results, and artifacts.

Default mode: read-only except for dedicated test fixtures and evidence paths leased by Prime.

Gauge reports failures; it does not rewrite production code during the same assignment.

### 7. Sentry — correctness, security, and regression reviewer

Sentry reviews the proposed change as an independent owner.

Responsibilities:

- Inspect the diff and the affected execution paths.
- Look for correctness defects, trust-boundary mistakes, exploit paths, data loss, race conditions, and missing cleanup.
- Check whether tests prove the claimed behavior rather than mirror the implementation.
- Rank findings by impact and confidence.
- Cite concrete evidence and avoid style-only feedback unless it hides a maintainability or correctness risk.

Default mode: read-only. Sentry never approves its own implementation.

### 8. Lens — visual, interaction, and device QA specialist

Lens validates what players actually see and operate.

Responsibilities:

- Review in-engine screenshots, captures, UI stories, and interactive flows.
- Check hierarchy, readability, input targets, clipping, scrolling, motion, and feedback.
- Compare work against approved references and the shared design system.
- Verify relevant desktop, mobile, controller, and aspect-ratio states.
- Record exactly which states were inspected and which remain untested.

Default mode: read-only except for evidence capture locations. Lens does not declare visual approval from source inspection alone.

### 9. Rigger — Roblox Studio, world, and asset integration specialist

Rigger owns operations that depend on live Studio state, place hierarchy, assets, animation, or world geometry.

Responsibilities:

- Inspect the intended place and confirm Edit or Play state before acting.
- Stage, preview, measure, and validate world or asset changes.
- Preserve source assets and use project-approved promotion paths.
- Capture hierarchy, geometry, animation, replication, and cleanup evidence.
- Treat content authored in the place file (anything outside the Rojo tree) as Studio-owned, and require code that depends on it to name the exact instance paths.
- Treat Studio, places, upload gates, and shared test servers as exclusive resources.

Rigger may mutate live project state only when the task explicitly authorizes it and Prime holds the appropriate resource lease.

### 10. Keeper — data, economy, configuration, and compatibility guardian

Keeper protects durable player and product contracts.

Responsibilities:

- Audit saved-data schemas, migrations, receipts, ownership, catalog IDs, probabilities, prices, rewards, and feature flags.
- Compare before-and-after configuration and public protocol behavior.
- Verify backward compatibility and rollback requirements.
- Flag changes that require approval from Jack or staged rollout.
- Produce invariant reports for monetization and progression work.

Default mode: read-only. Keeper may propose migrations or guards but should not execute irreversible operations.

### 11. Quill — documentation and release communication specialist

Quill turns verified work into durable, audience-appropriate communication.

Responsibilities:

- Update technical documentation, handoffs, changelogs, review packets, and release notes.
- Prepare player-facing copy, localization-ready strings, and operational checklists.
- Keep claims aligned with actual evidence and test status.
- Remove internal reasoning, secrets, and irrelevant implementation detail from external-facing language.
- Identify documentation that became stale because of the change.

Quill does not invent test results or change product behavior through documentation edits.

## Live task states

The live board uses exactly three task states.

### READY

The task can start now. Its required inputs exist, dependencies are satisfied, acceptance criteria are testable, and required resources are available or leasable.

### WAITING

The task is waiting on an event that can resolve without a new product decision, such as:

- a delegated agent result;
- a background build or test;
- a review response;
- an asset-processing operation;
- an already-requested action from Jack;
- a scheduled retry after a transient failure.

Every waiting task must record:

- `waiting_on` — the exact event;
- `wake_when` — the condition that makes it ready;
- `next_check` — when or how Prime should recheck it;
- `timeout_action` — retry, convert to blocked, or take a named fallback.

Waiting work must release any resource it no longer needs. An agent should not occupy a lane merely to poll.

### BLOCKED

The task cannot make meaningful progress without a new decision, permission, credential, missing source, or conflict resolution.

Every blocked task must record:

- the concrete blocking condition;
- checks already performed;
- the smallest action that would unblock it;
- safe work that can continue elsewhere.

A failed test with a known repair path is READY work, not a blocker.

### Active leases and completed work

Execution is represented by a lease separate from task status. A READY task may have an active lease containing the worker, leased paths, leased resources, start time, and expiry.

Completed work leaves the live board and is appended to a completed ledger with its result, evidence, and follow-up tasks. This preserves a three-state live queue without losing history. Its evidence folder moves from `tasks/` to `archive/` once its goal is finished (see Artifact layout).

## Prime's scheduling loop

Prime repeats this loop until the goal is achieved or all remaining work is genuinely blocked:

1. Ingest newly completed specialist results and external events.
2. Verify that returned artifacts exist and that reported checks match their saved evidence.
3. Archive completed tasks or create focused repair tasks.
4. Re-evaluate dependencies and promote eligible waiting tasks to READY.
5. Expire abandoned leases and recover their work safely.
6. Sort READY tasks by:
   - critical-path impact;
   - number of downstream tasks unblocked;
   - risk reduction;
   - player-visible value;
   - age;
   - estimated cost.
7. Match the highest-value task to the cheapest capable specialist lane.
8. Refuse a dispatch if its paths or exclusive resources overlap an active lease.
9. Dispatch independent work up to the configured concurrency limit.
10. Continue planning, integration, or another READY task instead of synchronously waiting on one lane.
11. When no READY work remains, recheck due waiting conditions.
12. If only blocked work remains, ask Jack for the smallest specific decision required.

Prime should keep enough capacity for integration and unexpected high-priority findings. Maximum concurrency is a ceiling, not a target.

## Task contract

Every delegated task should contain the following fields. A work packet must be understandable without the full parent conversation and small enough that the specialist does not need to rediscover the whole project.

```yaml
id: FEAT-001
title: Short, outcome-focused title
status: ready
priority: P1          # P0=blocker, P1=critical-path, P2=important, P3=nice-to-have
estimated_tokens: small  # small / medium / large — informs capability routing
role: mason
objective: One concrete outcome
reason: Why this work exists
depends_on: []
read_scope:
  - exact paths, symbols, artifacts, or URLs
write_scope:
  - exact paths or path patterns
resources:
  - named exclusive or shared resources
invariants:
  - behavior that must remain unchanged
acceptance:
  - observable pass conditions
checks:
  - commands or runtime scenarios
evidence_dir: .review/agent-workflow/tasks/FEAT-001
forbidden:
  - explicit out-of-scope actions
return_format: standard-result-v1
```

## Standard specialist return

Every specialist returns a concise summary in this form:

```text
RESULT: PASS | FAIL | WAITING | BLOCKED
SUMMARY: What was established or changed
CHANGED: Exact files or "none"
CHECKS: Commands/scenarios and outcomes
EVIDENCE: Paths to durable artifacts
UNVERIFIED: Anything not actually exercised
RISKS: Remaining material risks
NEXT: Suggested follow-up tasks
```

Raw logs, large diffs, screenshots, and generated reports belong in the evidence directory, not in the message to Prime.

Each evidence artifact must record the task ID, the source state it was reviewed against (commit or file hashes when relevant dirty or untracked files exist), and the environment or scenario used. Prime compares evidence against the candidate integration state and invalidates affected results after material changes. For Roblox-specific evidence, include place identity, Studio state, and capture identifiers when those facts affect the result.

## Ownership and concurrency rules

### File leases

- Prime is the only writer of the task board.
- A specialist may edit only its leased write scope.
- Two active tasks may not write the same file or generated output tree.
- Read-only work may run alongside a writer unless it depends on a stable snapshot of files being changed.
- Before integration, Prime inspects the current diff rather than relying on an earlier snapshot.
- Specialists do not stage, commit, rebase, reset, or discard work unless the task explicitly grants that authority.

### Lease lifecycle

- A lease begins when Prime dispatches a task and ends when the specialist returns its result.
- A lease is abandoned if the specialist errors out or produces no output or progress signal. Prime reclaims the write scope and preserves partial work in the evidence directory without integrating it.
- A specialist may request a lease extension with justification. Prime grants it or splits the remaining work into a new task.
- When a lease expires or is reclaimed, no other agent may integrate the partial work without Prime's review.
- Lease expiry removes authorization but does not prove the old worker has stopped. Before reassigning writable resources, Prime must stop the old worker or confirm its output is isolated. Do not reclaim a resource solely because a timer elapsed if the worker may still be writing.

### Exclusive resources

Examples of exclusive resources include:

- a Roblox Studio instance;
- a specific place in Edit or Play mode;
- a Rojo port;
- a local test server;
- a generated build directory;
- an asset-upload or publishing gate;
- a shared external review session.

Prime grants and releases these resources explicitly. A waiting task should release a resource unless retaining it is essential and recorded.

### Gates requiring Jack's authorization

Require explicit authorization from Jack for material external or irreversible actions, including:

- publishing a live place or release;
- introducing or retaining a proposed failure screen or deliberate join/play block as the response to an error, including a critical error;
- changing monetization, prices, probabilities, or rewards;
- executing a destructive data migration;
- uploading or deleting production assets;
- sending external communications;
- changing secrets, credentials, or access controls;
- widening scope beyond Jack's stated goal.

### Task handoffs

When work transfers between agents, the handoff must contain the task contract, relevant source files or snapshot, accepted decisions, current diff, evidence paths, and unresolved questions. Do not depend on shared chat history or provider-specific conversation state being portable. The receiving worker verifies that its tools and source state match the assignment before claiming results.

A Prime transfer requires a checkpoint of the board, all decisions, partial work, and active leases, plus cessation of the outgoing Prime's authority. There must never be two coordinators writing the same board.

## Failure escalation

When a specialist returns FAIL or a downstream gate reveals a defect, Prime classifies the failure and responds accordingly:

- **Rework within scope.** The failure is local to the specialist's assignment. Prime creates a focused repair task for the same or an equivalent specialist, citing the specific evidence.
- **Rework across roles.** The failure implicates an upstream decision — for example, a Sentry finding that requires an Architect redesign. Prime reopens the upstream task, invalidates downstream evidence that depended on the original decision, and re-dispatches affected work.
- **Scope violation.** A specialist modified files or resources outside its lease. Prime stops the offending worker and preserves its diff and evidence. Prime identifies changes attributable to that worker and removes only those, taking care not to discard concurrent work from other specialists. If attribution is ambiguous, Prime quarantines the affected files, pauses that scope, and asks Jack for the specific recovery decision.
- **Cascading failure.** Multiple tasks are affected, the root cause is unclear, or the repair path is ambiguous. Prime halts the affected subtree of tasks, summarizes the situation with evidence, and escalates to Jack for a decision.

A failed test with a known, bounded repair is READY work, not a blocker. Repeated failure on the same task without a changed condition is a blocker and must be escalated.

## Conflict resolution

When specialists return contradictory recommendations, Prime:

1. Identifies whether the disagreement is factual (different assumptions) or evaluative (different values or priorities).
2. Requests targeted clarification from the dissenting specialists, scoped to the specific disagreement.
3. Decides based on Jack's stated intent, acceptance criteria, and evidence weight.
4. Records the decision and rationale in `decisions.md`.
5. Escalates to Jack when the conflict involves a product-level tradeoff that acceptance criteria do not resolve.

## Quality gates

Prime selects gates according to risk. Not every task requires every gate.

### Code gate

- Focused implementation is complete.
- Formatting, linting, typing, and relevant automated tests pass.
- Unrelated working-tree changes remain untouched.
- No acceptance criterion relies solely on code inspection when runtime evidence is required.

### Review gate

- Sentry reviewed the final diff and affected execution path.
- Startup, loading, and dependency changes preserve continued play through failures, including degraded or broken gameplay. Any proposed failure screen or deliberate join/play block has Jack's explicit approval; severity alone is not approval. Review the failure, exception, timeout, and late-completion paths, and require behavioral regression evidence for changed readiness gates. Flag existing blockers encountered during review instead of silently treating them as approved precedent.
- Material findings are fixed, explicitly accepted, or converted into tracked work.
- The reviewer is independent from the implementation assignment.

### Runtime gate

- Gauge exercised the relevant behavior in the appropriate environment.
- Results include exact commands or reproduction steps.
- Skipped scenarios are labeled `NOT RUN`, never implied to have passed.

### Visual gate

- Lens inspected actual rendered or in-engine states.
- Required devices, aspect ratios, and interaction states are recorded.
- Approved visual references and shared components were used where applicable.

### Roblox integration gate

- Rigger verified the intended place, hierarchy, mode, and cleanup state.
- Studio-only or replication behavior has real Studio evidence.
- Temporary probes, previews, and fixtures are removed before completion.

### Data and economy gate

- Keeper confirmed protected IDs, values, schemas, receipts, and ownership behavior.
- Migration and rollback behavior are defined when durable data changes.
- Product-sensitive changes have Jack's approval.

### Documentation gate

- Quill updated durable instructions and release communication when needed.
- Documentation distinguishes verified results, planned work, and known limitations.

## Default workflow recipes

### New gameplay feature

1. Scout maps current behavior and relevant constraints.
2. Forge defines the player experience and acceptance criteria.
3. Architect defines interfaces and state ownership if the feature crosses subsystems.
4. Prime approves the implementation boundary.
5. Mason implements.
6. Gauge and Sentry independently test and review in parallel.
7. Lens, Rigger, or Keeper joins only if the feature touches their domain.
8. Quill updates durable documentation and release notes.
9. Prime verifies evidence and integrates the result.

### Bug fix

1. Scout reproduces and traces the failure.
2. Prime converts the verified cause into a bounded repair task.
3. Mason implements the smallest fix and regression test.
4. Gauge reproduces the original failure against the fix.
5. Sentry reviews regression and edge-case risk.
6. Prime closes the task or creates a focused follow-up.

### UI or interaction change

1. Scout locates current components, states, and project design guidance.
2. Forge specifies interaction and visual intent.
3. Mason implements with shared tokens and components.
4. Lens captures and reviews required states and devices.
5. Gauge checks functional behavior; Sentry checks state and network boundaries.
6. Quill updates player-facing strings or guidance.

### World, build, animation, or asset work

1. Scout inventories sources and prior evidence.
2. Forge defines gameplay purpose and measurable constraints.
3. Architect defines runtime ownership if new systems are required.
4. Rigger stages and measures the content under an exclusive Studio lease.
5. Mason implements supporting code when needed.
6. Gauge validates gameplay behavior; Lens validates presentation.
7. Sentry reviews cleanup, replication, and failure handling.
8. Prime controls promotion and final integration.

### Release preparation

1. Prime freezes scope and creates a release checklist.
2. Gauge runs the release test set.
3. Sentry reviews the final diff and unresolved risk ledger.
4. Lens and Rigger verify player-facing and Studio-dependent surfaces.
5. Keeper checks configuration, economy, and compatibility.
6. Quill prepares patch notes, handoff, and rollback instructions.
7. Prime presents the evidence and requests release approval from Jack.

## Token-efficiency policy

Using more agents saves time and tokens only when assignments are bounded. Uncontrolled fan-out duplicates repository reads and increases cost.

### Context diet

- Give specialists the task contract, applicable project rules, and targeted files only.
- Do not copy the entire parent conversation into every lane.
- Use Scout's memo as shared context instead of making every worker repeat discovery.
- Link to large files and specify headings, symbols, or line ranges to inspect.
- Store logs and screenshots in artifacts; return one-screen summaries.

### Capability routing

- Use the least expensive capable reasoning tier for each role.
- Reserve the strongest reasoning for Prime, difficult architecture, ambiguous design, and high-risk adjudication.
- Use fast workers for targeted searches, mechanical edits, test execution, and documentation formatting.
- Escalate a task only after the cheaper lane identifies a concrete reason.
- A stronger model does not fix missing tools, missing authorization, or an unavailable test environment. Escalate reasoning only when the task itself is genuinely harder.

### Capacity management

Jack's subscriptions have daily and monthly usage limits that agents cannot directly query. Prime must manage capacity through behavioral rules:

- **Session budgeting.** At the start of a work session, assess the scope of remaining work and allocate capacity accordingly. Do not burn the full daily allowance on the first task if multiple tasks are queued.
- **Progressive consolidation.** When capacity is limited or the session is long, consolidate roles more aggressively — combine Scout + Mason, Gauge + Sentry, or have Prime handle small tasks directly. The role contracts still apply; only the dispatch changes.
- **Conserve on success, spend on failure.** Work that is passing gates smoothly should use cheaper tiers. Reserve expensive reasoning for tasks that have already failed at a cheaper tier, ambiguous requirements, or safety-critical review (economy, data, monetization).
- **Observable signals to conserve:** rate-limit warnings from the provider, slow response times, repeated context-window truncation, or Jack saying capacity is low. When any of these appear, reduce active lanes and consolidate remaining work.
- **Never waste capacity re-reading the whole repo.** Reuse Scout memos and prior evidence. The most expensive operation is making every new specialist rediscover the project from scratch.

### Controlled fan-out

- Do not delegate trivial one-file changes unless independence or verification justifies it.
- Spawn multiple agents only for tasks that can proceed independently.
- Avoid asking two agents the same broad question unless deliberate independent review is worth the cost.
- Prefer one Scout memo followed by several narrow consumers.
- Stop a lane as soon as its contract is satisfied or it reaches a declared blocker.

### Reusable memory

- Record stable architectural decisions, commands, and project rules in repository documentation.
- Record task-specific evidence under `.review/agent-workflow/tasks/<ID>/`.
- Reuse verified memos while their referenced commit and environment remain current.
- Invalidate memos when affected files, configuration, or runtime state changes.

### Bounded retries

- Retry transient operations only according to the task's timeout policy.
- Do not repeat the same failed action without a changed condition.
- Convert repeated uncertainty into a focused Scout task or a clear blocker.

### No-guess rule (DEC-008)

- An asset missing from where code expects it is a question for Jack, never a reason to build a substitute. Report BLOCKED with the paths and searches you tried.
- Core design choices are proposed as `PENDING JACK: Q<n>` with a recommendation, and nothing is built on them until Jack answers. A task contract must not settle an open design question implicitly.
- Before dispatching a build lane, Prime lists the contract's assumptions about existing content and design intent. Unconfirmed assumptions become questions for Jack.
- Agent-built instances carry a `BuiltBy` attribute and are listed in evidence.

### Session lessons (DEC-007)

- Route by cost: sonnet for bounded lanes, haiku for mechanical edits and log greps, opus only for judgment (Sentry, Architect, Forge, hard Rigger work).
- Before writing a kickoff or handoff, and at session start, check each listed step against its evidence file and that file's age relative to the source it covers. Reuse current evidence instead of redoing it.
- Rojo syncs `src/` into Studio live. Don't run code lanes during a Studio runtime run whose evidence depends on that code. Use worktree isolation for code lanes once a committed base exists.
- Luau code gate: `scripts/gate.sh <files>` (no args = changed and untracked files).
- TestEZ: set `workspace:SetAttribute("RunTests", true)` in Edit mode, Play, then clear it. Never edit `TESTS_ENABLED` for a run.
- Every evidence file starts with `RESULT: PASS|FAIL|WAITING|BLOCKED` on its first line.
- Docs lanes run alongside verification by default.
- Test only what can't be inferred (Jack, 2026-10-14). If a change's outcome follows from logic already proven, such as an asset swap with the same contract, skip the runtime check and say so. Runtime and Gauge effort goes to new gameplay, batched into one run per milestone. Legacy code is not re-verified for its own sake.
- Put receipt, economy and validation logic in ModuleScripts so specs can require it.

## Artifact layout

All task-specific files live under `.review/agent-workflow/`:

```text
.review/agent-workflow/
  board.json
  completed.ndjson
  decisions.md
  tasks/              # active, in-progress, or unfinished work only
    FEAT-001/
      scout-memo.md
      design.md
      test-output.txt
      review.md
      screenshots/
      FEAT-001A/      # subtask of FEAT-001
  archive/            # finished work and work no longer being pursued
    PERF-001/
```

- Every task-specific file belongs in its task folder: memos, designs, plans, reviews, audit reports, test output, and screenshots. Never put one in `docs/`, at the `.review/` root, or at the `.review/agent-workflow/` root.
- Subtasks nest inside their goal's folder, so one move archives the whole goal.
- `tasks/` holds only work that is active, in progress, or unfinished. When a goal is completed and verified, or Jack stops pursuing it, Prime moves its whole folder to `archive/`. To reopen archived work, move the folder back to `tasks/`.
- Record evidence paths in `board.json` and `completed.ndjson` relative to the task folder (e.g. `FEAT-001/review.md`) so they stay valid after archiving.

### Board and ledger formats

`board.json` is one object: `goal` (the active goal ID), `source_commit`, `plan` and `decisions` (paths relative to `tasks/`), `streams` (one-line status of each exclusive resource, such as Studio or the working tree), and `tasks`. Each task entry carries `id`, `status` (`ready`, `waiting`, `blocked`, or `done` while it still needs review notes), optional `role`, `model` (a lane hint), `lease` (`write` paths and `resources`), `blocking` or the waiting fields from the task states above, `note`, and `evidence` (a path relative to the task folder, such as `FEAT-001/review.md`). Prime updates it atomically and is its only writer.

`completed.ndjson` has one JSON object per line, appended when a task leaves the board: `{"id", "title", "result", "completed_at", "evidence"}` with `result` set to PASS, FAIL, or a short disposition.

`decisions.md` records each decision as `## <GOAL> / DEC-###: <title>` with Date, Source, and Decision lines, newest first. Never reuse a number.

The live board is operational state and may remain untracked. Stable decisions, specifications, and approved behavior should be moved into the repository's durable documentation.

`board.json` and `completed.ndjson` are operational state and should be `.gitignore`d. Evidence files — memos, test output, screenshots, and reviews — should be committed alongside the code they document.

## Success metrics

Track workflow quality over time rather than optimizing for the number of active agents.

- Lead time from request to verified result
- Percentage of specialist tasks accepted without rework
- Defects found before integration versus after integration
- Duplicate repository exploration per task
- Tokens used per accepted deliverable
- Waiting time caused by resource contention
- Number of conflicting concurrent edits
- Percentage of claims backed by saved evidence
- Number of escaped regressions
- Decisions escalated to Jack with sufficient context on the first attempt

If token use rises without corresponding reductions in lead time or defects, reduce fan-out, tighten task packets, or consolidate overlapping roles.

## Adoption sequence

### Stage 1 — contracts

- Establish Prime, the three-state board, task contracts, result format, and file leases.
- Begin with Scout, Mason, Gauge, and Sentry.

### Stage 2 — product specialization

- Add Forge, Lens, Rigger, Keeper, Architect, and Quill as tasks require them.
- Define project-specific quality gates and exclusive resources.

### Stage 3 — automation

- Add atomic board updates, lease expiry, artifact checks, and status summaries.
- Connect existing test, review, capture, and validation scripts.

### Stage 4 — optimization

- Measure rework, token use, and wait time.
- Adjust routing and concurrency based on evidence.
- Keep agent instructions short and move repeatable procedures into reusable workflow modules.

## Definition of done

Prime may declare Jack's goal complete only when:

- every required deliverable exists;
- acceptance criteria are satisfied;
- appropriate checks have passed;
- evidence is saved and referenced;
- material review findings are resolved or disclosed;
- temporary resources and probes are cleaned up;
- no required task remains READY, WAITING, or BLOCKED;
- the final response states what changed, what was verified, and any remaining limitation.

