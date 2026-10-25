# M5-SENTRY-REMOTES: Sentry Remote Exploit & Authority Security Audit
Model: sonnet / sentry   Studio: no   Depends on: none   Size: M

## Goal
Perform a rigorous Sentry security audit of every client-callable Knit remote function and signal across the entire backend (revival-plan §4.8, §8 M5):
- Ensure strict server-side authority: client never dictates rewards, prices, inventory items, or stats.
- Parameter validation: verify type assertions, range clamps, and sanitization on all client inputs.
- Rate-limiting & debouncing: protect against spamming, double-clicks, and replay attacks.
- Distance & state validation: ensure physical proximity checks on world interactions.
- Apply immediate hardening fixes where needed and document findings in `R2-SECURITY/review.md`.

## Read (only these)
- `docs/AI_AGENT_WORKFLOW.md` (Sentry role contract)
- `docs/CONVENTIONS.md` (Security and server authority rules)
- `src/server/Modules/QuestService.luau`
- `src/server/Modules/DailyRewardService.luau`
- `src/server/Modules/TreasureHuntService.luau`
- `src/server/Modules/EventService.luau`
- `src/server/Modules/ShiftService.luau`
- `src/server/Modules/OrderService.luau`
- `src/server/Modules/CapsuleService.luau`
- `src/server/Modules/RealOrderService.luau`

## Write scope
- `src/server/Modules/QuestService.luau` (hardening edits if needed)
- `src/server/Modules/DailyRewardService.luau` (hardening edits if needed)
- `src/server/Modules/EventService.luau` (hardening edits if needed)
- `src/server/Modules/ShiftService.luau` (hardening edits if needed)
- `src/server/Modules/OrderService.luau` (hardening edits if needed)
- `src/server/Modules/CapsuleService.luau` (hardening edits if needed)
- `src/server/Modules/RealOrderService.luau` (hardening edits if needed)
- `.review/agent-workflow/tasks/REVIVAL-001/R2-SECURITY/review.md` (new)

## Steps
1. Audit each client-exposed method in:
   - `QuestService.Client:ClaimQuest(player, index)`: verify `typeof(index) == "number"`, integer clamp, valid index range.
   - `QuestService.Client:RerollQuest(player, index)`: verify `typeof(index) == "number"`, integer clamp, valid index range, BobaBucks balance check.
   - `DailyRewardService.Client:ClaimReward(player)`: verify in-flight claim locking, 20h cooldown check, single claim per day.
   - `EventService.Client:StartEvent(player, eventName)`: verify `typeof(eventName) == "string"`, valid event key, rank >= 10 check, 30m server cooldown check.
   - `ShiftService.Client:SetClockedIn(player, clockedIn)`: verify `typeof(clockedIn) == "boolean"`, debounce against rapid toggling.
   - `OrderService.Client`: verify order creation sanitization, item count clamping, and no client-side price overrides.
   - `CapsuleService.Client:TryCompleteReadyHatch(player)`: verify server validates hatch duration, rejects early calls.
   - `RealOrderService.Client`: verify barista rating clamping (1..5), order creation limits.
2. Apply hardening edits to any service where an input check or guard is missing.
3. Run WSL gate check on all modified services: `. .review/agent-workflow/tools/wsl/env.sh && gate <files>`
4. Write comprehensive security audit evidence to `.review/agent-workflow/tasks/REVIVAL-001/R2-SECURITY/review.md`.

## Done when
- All Knit client endpoints are audited against the 4 exploit vectors (type poisoning, spam, authority bypass, distance).
- Any discovered vulnerabilities are patched and pass WSL gates.
- `R2-SECURITY/review.md` records the audit summary.

## Checks to run
- `. .review/agent-workflow/tools/wsl/env.sh && gate src/server/Modules/QuestService.luau src/server/Modules/DailyRewardService.luau src/server/Modules/EventService.luau src/server/Modules/ShiftService.luau src/server/Modules/OrderService.luau src/server/Modules/CapsuleService.luau src/server/Modules/RealOrderService.luau`

## STOP-AND-ASK
- none

## Evidence
`.review/agent-workflow/tasks/REVIVAL-001/R2-SECURITY/review.md`
