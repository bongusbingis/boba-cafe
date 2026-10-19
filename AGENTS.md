# AGENTS.md — boba-cafe agent entrypoint

Provider-neutral. Claude Code, Codex, and any other coding agent work from the
same documents and the same live board. Nothing here replaces those sources.

## Read first

1. `docs/AI_AGENT_WORKFLOW.md` — Prime + specialist roles, task contracts,
   leases, gates, evidence layout. Roles are vendor-neutral; follow your
   current role's contract.
2. `docs/CONVENTIONS.md` — product priorities (monetization, engagement,
   retention, CCU), continued-play rules, Luau/Knit/React patterns.
3. `docs/ARCHITECTURE.md`, `docs/SYSTEMS.md`, `docs/STYLE.md` — structure,
   system invariants, UI tokens.

## Live state

- Board: `.review/agent-workflow/board.json`, `completed.ndjson`,
  `decisions.md` (DEC-### series starts there). The board and ledger are
  local operational state (gitignored); create them from "Board and ledger
  formats" in the workflow doc if they are missing.
- Task evidence: `.review/agent-workflow/tasks/<ID>/`; finished work moves to
  `archive/`. Never put task docs in `docs/` or at `.review/` root.
- Board `model` labels (`opus`/`sonnet`/`haiku`) are Claude lane hints, not
  requirements. Any agent may work any lane within its role contract.

## Boundaries

- `.claude/` belongs to Claude Code. Other agents read nothing from it and
  write nothing to it.
- Jack approvals (never infer): failure screens or join/play blocks,
  publishing/releasing, uploads, economy/prices/probabilities/rewards
  (BobaBucks, Points, gamepasses, developer products, capsule/shop catalogs,
  promo codes), destructive data migrations (including bumping the
  ProfileStore name), secrets/credentials, scope widening.
- Never guess on core design or existing content (DEC-008). If an expected
  asset isn't where code expects, stop and report BLOCKED with what you
  searched; Prime asks Jack. Never build a substitute, and never record "not
  found" as "doesn't exist". Core design choices (loop, roles, progression,
  station/recipe flow, new content's look) are proposed as `PENDING JACK`
  questions, not decided. Anything agents build after Jack confirms carries a
  `BuiltBy` attribute.
- Content authored in the place file (`workspace.Assets`, `Ordering System`,
  `ReplicatedStorage.SelectorModels`, `ReplicatedStorage.Networking`,
  `SoundService.SFX`) is not in the Rojo tree. Changing it needs Studio and a
  Rigger lease; code that depends on it must name the exact instance paths.
- UI replicates the existing style exactly (DEC-013). `docs/STYLE.md` is the
  spec: use only its tokens, components and patterns. A new token, component,
  or visual pattern needs Jack's approval; if nothing fits, stop and ask.

## Gates

- Luau: Selene, StyLua (`--check`), `rojo build default.project.json -o <path
  outside the repo>`, and the TestEZ suite in Studio (set `TESTS_ENABLED = true`
  in `src/server/Tests/RunTests.server.luau` locally and revert before
  finishing).
- The tree already has Selene and StyLua findings (baseline in DEC-001). The
  gate is no new findings in files you changed, not a clean repo.
