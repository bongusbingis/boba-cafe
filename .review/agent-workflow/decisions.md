# Architectural & Optimization Decisions

Newest first. Each entry is `## <GOAL> / DEC-###: <title>` with Date, Source, and Decision. Prime is the only writer. Numbering continues; never reuse a number.

## REVIVAL-001 / DEC-008: No guessing on core design or existing content

- **Date:** 2026-10-14.
- **Source:** Jack. M0.1 built a new `SyrupDispenser` because the plan assumed none existed. Jack's own model was in ServerScriptService's Archive/Services/KitchenService. In Jack's words: "that should have been a question asked to me rather than guessing like it did which produced a low quality results. Do not make guesses for such core design decisions like this without confirming with me."
- **Decision:**
  - **Missing or misplaced content:** if code expects an asset (model, tool, animation, sound, area) and an agent can't find it where expected, that is a question for Jack. It is never a reason to build a substitute.
    - Agents report BLOCKED with what they searched.
    - Prime asks Jack where the asset is, or whether it exists.
    - "Not found by search" is never recorded as "does not exist".
  - **Core design decisions** are Jack's: loop structure, what gets cut or kept, roles, progression shape, station or recipe flow, and the look of any new content. Specialists propose them as questions with a recommendation, marked `PENDING JACK`, and nothing is built on them until Jack answers.
  - **Assets agents build** (only after Jack confirms none exists) carry a `BuiltBy` attribute, and are listed in the task evidence.
  - **Prime's check:** before any lane builds, Prime scans the contract for assumptions about existing content and design intent, and turns them into questions for Jack.
- **Applies retroactively:** every `BuiltBy`-tagged instance from M0.1 is listed for Jack's review (M0.11).

## REVIVAL-001 / DEC-007: Workflow efficiency changes

- **Date:** 2026-10-14.
- **Source:** Jack ("do as many defensible changes as you want"; "use sonnet (and maybe haiku) where applicable"; no manual setup on his end). Prime chose the changes after this session's lessons.
- **Decision:**
  - **Model routing:** sonnet is the default for bounded lanes (Mason, Gauge, Quill, Scout). Haiku is for mechanical work: exact-text edits, file moves, log greps. Opus is only for Sentry, Architect, Forge, and Rigger work that needs judgment.
  - **Kickoffs are checked against evidence:** before writing a kickoff or handoff, and at session start, Prime confirms that each "next step" has no evidence file already, or that the existing file predates the source it covers (`find src -newer <evidence>`). Completed evidence that is still current is reused, not redone.
  - **Rojo live-sync rule:** `src/` edits sync into Studio, so code lanes must not run during a Gauge Studio session whose evidence depends on that code. Worktree isolation (`Agent isolation: worktree`) is used for code lanes only once a committed base exists, because worktrees start from HEAD.
  - **Code gate is `scripts/gate.sh <files>`:** it reports no new Selene or StyLua findings versus HEAD and runs `rojo build` outside the repo. `rokit.toml` pins selene and stylua so the shims resolve.
  - **TestEZ without editing the file:** in Edit mode Gauge runs `workspace:SetAttribute("RunTests", true)`, plays, then clears the attribute. The Studio-only guard is in `RunTests.server.luau`.
  - **Evidence files start with a `RESULT:` line**, so Prime can read status with `head -3`.
  - **Docs lanes run alongside verification by default**, accepting a small follow-up edit if a repair changes a contract.
  - **Testability:** new receipt, economy and validation logic goes in ModuleScripts that specs can require. Logic inside `.server` scripts can't be tested.
- **Not adopted:** standing approval for M1 design lanes. That is Jack's gate (M1 go).

## REVIVAL-001 / DEC-006: Skip Hatch is invalid without an active hatch

- **Date:** 2026-10-14.
- **Source:** Jack ("dont allow purchase if their not hatching; that shouldnt be possible theoretically so its an invalid purchase").
- **Decision:**
  - The client must never prompt the Skip Hatch product unless a hatch is pending.
  - If a receipt arrives anyway with no hatch pending, the server treats it as invalid: it grants nothing and does not return `PurchaseGranted` (return `NotProcessedYet`, so Roblox keeps the receipt unconsumed).
  - No skip credit is stored.
- The 5 sound assets that fail permission checks are Jack's to fix later. They are not tracked as agent work.

## REVIVAL-001 / DEC-005: Reuse the existing map; never delete it

- **Date:** 2026-10-13.
- **Source:** Jack.
- **Decision:**
  - Do not delete the existing map. Build the new gameplay in it.
  - Limiting where players can go or what they can see is the preferred way to focus the experience (a Forge item for M2).
  - A completely separate new area is allowed only if Prime is certain it will look hand-made rather than AI-generated or sloppy. The default is no.
  - Legacy `OldScriptables` content is moved or cloned, never destroyed, and is backed up before it is moved.

## REVIVAL-001 / DEC-004: Join kick removal approved; M0 and M1.1 approved to start

- **Date:** 2026-10-13.
- **Source:** Jack ("confirm, this was just a debug thing"; "approved").
- **Decision:** The rank-<4 kick in `src/server/init.server.luau` was a debug lock and is removed in M0. M0 (foundation) and M1.1 (order-spec design) are approved to start.

## REVIVAL-001 / DEC-003: Revival plan v2 adopted as the working plan

- **Date:** 2026-10-13.
- **Source:** Prime (second session) review of code, Studio place, and live Roblox data; Jack asked for a comprehensive plan to test-ready and release, no changes yet.
- **Decision:** `tasks/REVIVAL-001/revival-plan.md` replaces the phase plan in `handoff.md` §4 (handoff kept as history). Milestones M0–M7; M1 "serve one NPC" vertical slice proves the loop before breadth. World wiring reuses `workspace.OldScriptables` (legacy givers, ordering system, NPC nodes already aligned with the new map) instead of building proxy models.

## REVIVAL-001 / DEC-002: Release target, legacy data, passes, ranks, resources

- **Date:** 2026-10-13.
- **Source:** Jack (answers to Prime's questions).
- **Decision:**
  - Ship over the same place 718328620. Full fresh start: no legacy currency or items are carried over.
  - Every legacy gamepass is remapped to a perk. The pass catalog must let any off-sale legacy pass be listed again without code changes.
  - Group ranks become titles, moderation, and event hosting, with no gameplay gating.
  - Solo + AI agents only: no commissioned art and no ad budget.

## SETUP-001 / DEC-001: Agent workflow adopted; tooling baseline recorded

- **Date:** 2026-10-12.
- **Source:** Jack's request to port the agent workflow and documentation structure into this repository.
- **Decision:** `AGENTS.md`, `docs/AI_AGENT_WORKFLOW.md`, `CONVENTIONS.md`, `ARCHITECTURE.md`, `SYSTEMS.md`, and `STYLE.md` are the governing documents. Task evidence lives under `.review/agent-workflow/tasks/<ID>/` and moves to `archive/` when finished.
- **Tooling baseline (before any agent change):** `rojo build default.project.json` succeeds. Selene reports 201 errors and 63 warnings. `stylua --check src` flags 99 files. No Studio TestEZ run was performed (`TESTS_ENABLED = false`). The gate for a change is no new findings in the files it touches, not a clean repository.
- **Not verified:** All system descriptions in `SYSTEMS.md` were read from source and have not been exercised in Studio.
