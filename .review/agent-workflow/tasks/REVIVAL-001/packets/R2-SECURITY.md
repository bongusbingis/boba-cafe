# R2-SECURITY: Sentry review of client remotes and the DEC-031 refund path
Role: sentry (read-only)   Studio: no   Depends on: checkpoint f06a9bf + Prime D1 corrections   Size: M
Supersedes the abandoned M5-SENTRY-REMOTES lane (that lane edited code; this one must not).

## Objective
Independent review of every client-callable remote added or changed since `cbf5271`, plus the
DEC-031 BobaBucks refund path. Report exploits, money/data loss, duplicate grants, and
continued-play violations only (DEC-017). Do not report style.

## Read (only these, line ranges via grep)
- `docs/AI_AGENT_WORKFLOW.md` (Sentry role, review gate), `AGENTS.md`
- `.review/agent-workflow/decisions.md` DEC-017, DEC-019, DEC-029, DEC-031, DEC-032, DEC-033
- `git diff cbf5271 -- <file>` for each file below
- Remotes: `CapsuleService.luau` (Client table + PurchaseNametagCapsules, PurchaseDeterministicNametag,
  TryCompleteReadyHatch, refund helpers lines ~57-200, completePendingHatches),
  `DailyRewardService.luau`, `QuestService.luau`, `EventService.luau`, `GroupBenefitService.luau`,
  `TreasureHuntService.luau` (ProximityPrompt claim path), `ShiftService.luau` Client:SetClockedIn,
  `OrderService.luau` Client:CreateOrder/LeaveQueue, `CustomerService/init.luau` Client,
  `KitchenService/init.luau` Client, `SpillService/init.luau` Client, `BadgeService.luau` Client:AwardBadgeByName,
  `ProcessReceipt.server.luau` (Boba Party slot), `CurrencyService.luau` (Modify, TrySpendAsync),
  `DataService/init.luau` SaveAsync.

## Write scope
- `.review/agent-workflow/tasks/REVIVAL-001/R2-SECURITY/review.md` (new). Nothing else.

## Forbidden
- Editing any file under `src/`, docs, board, ledger, or decisions. No Studio, Play, or TestEZ. No git writes.

## Return
review.md first line `RESULT: PASS|FAIL`. Then findings ranked P0-P3, each with file:line,
concrete exploit/failure scenario, and a suggested fix in one or two sentences. Separate
CONFIRMED (traced through code) from PLAUSIBLE. Record the reviewed file hashes
(`git hash-object`). Reply to Prime in <=250 words, standard RESULT format.
