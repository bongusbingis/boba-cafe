# Boba Cafe — Context Map

Generated 2026-10-24 by the Primary Reasoning Agent for the FTUE audit.
Purpose: a fresh session should be able to orient itself in ~2 minutes from this file.

## The 5-Minute Tour (read in this order)

1. `.review/agent-workflow/CURRENT_STATE.md` — the active constitution. All authoritative rules distilled from the decisions ledger. If a rule is not here it is superseded.
2. `docs/SYSTEMS.md` — canonical per-system reference: owner modules, invariants, protected contracts, unverified/verified markers. Long; skim the system headings, read the ones you touch.
3. `src/server/Modules/CustomerService/init.luau` — the heart of the game loop: NPC pacing, tickets, Take Order/Serve prompts, payout, team combo, and the FTUE auto-grant + onboarding analytics. (`CustomerService/Npc.luau`, `Rules.luau`, `Seats.luau`, `CounterLock.luau` are its satellites.)
4. `src/server/Modules/KitchenService/init.luau` + `src/shared/Kitchen/Recipes.luau` — station prompts, the interaction runner, and every recipe (cup dispensers, Milk/Syrup/Tapioca, Coffee Machine, the Sink Washout). `KitchenService/Actions/*` are the action primitives.
5. `src/server/Modules/ShiftService.luau` — clocked in/out state (a `ClockedIn` attribute), shift lifecycle, first-shift completion (funnel step 6), and the `ShiftEnding` signal every progression hook listens to.
6. `src/shared/Ordering/OrderSpec.luau` — how an order becomes a spec and how a finished tool is graded (`Perfect`/`Close`/`Wrong`) purely from tool attributes. This contract is load-bearing for both serving and the recipe-card UI.

Then, as needed: `src/server/Modules/AnalyticsEvents.luau` (all funnel/economy events), `src/client/Modules/KitchenController.luau` (client guidance/hints), `src/client/Modules/OrderController.luau` (ticket listener), `src/shared/Configuration/CustomerConfig.luau` (FTUE constants).

## Where to find what

| Domain | Files |
| --- | --- |
| FTUE / onboarding | `CustomerConfig.luau` (`FIRST_SESSION_ORDERS`, `FIRST_SESSION_COUNT`, `AUTO_GRANT_FIRST_ORDER`, `AUTO_GRANT_TUTORIAL_ORDERS`), `CustomerService/init.luau` (`_checkAutoGrantFirstOrder`, `_autoGrantFirstOrder`, `_onServeTriggered`), `AnalyticsEvents.luau` (steps 1–8), `ShiftService.luau` (steps 2 & 6), `DataService/PlayerSetup.luau` (nickname, step 7), `ProgressionService.luau` (FirstLevelUp, step 8), `CapsuleService.luau` (`ShiftEnding` listener, Starter Capsule), `DailyRewardController.luau` (auto-open after first serve), `KitchenController.luau` + `KitchenGuidance.luau` (client hand-holding) |
| Economy | `CurrencyService.luau`, `StatisticsService.luau`, `AnalyticsEvents.luau` (`Economy`), `Server/Scripts/ProcessReceipt.server.luau`, `CapsuleService.luau`, `DailyRewardService.luau`, `QuestService.luau`, `LeaderboardService.luau` |
| UI | `shared/UI/` (App, Styles, Components, Pages), `client/Modules/App/`, `client/Modules/*Controller.luau` (dialog hosts), `docs/STYLE.md` (the visual spec; strict) |
| Kitchen | `server/Modules/KitchenService/` (`init`, `InteractionRunner`, `PromptBuilder`, `ActionRegistry`, `Actions/*`, `PourMoments`), `shared/Kitchen/Recipes.luau` + `RecipeConstructors.luau` + `KitchenTypes.luau` + `PourMeter.luau`, `shared/Configuration/KitchenConfig.luau`, `client/Modules/KitchenController.luau` + `KitchenGuidance.luau` |
| Customers / orders | `server/Modules/CustomerService/` (`init`, `Npc`, `Rules`, `Seats`, `CounterLock`), `server/Modules/OrderService.luau`, `server/Modules/RealOrderService.luau`, `shared/Ordering/` (`Menu`, `OrderSpec`, `MistakeText`) |
| Shifts / teams | `server/Modules/ShiftService.luau`, `server/Scripts/Teams.server.luau`, `shared/Configuration/ShiftConfig.luau`, `shared/Configuration/TeamsConfig.luau` |
| FTUE measurement | `server/Modules/AnalyticsEvents.luau` — `OnboardingFunnel` (native `LogOnboardingFunnelStepEvent`) and `Funnel` (legacy `LogFunnelStepEvent`) are both fired at every step; both dedupe per player per step index **per session** (in-memory, cleared on `PlayerRemoving`) |

## Common Traps

1. **Signal crashes propagate to the caller.** `Knit` client signals (`self.Client.X:Fire`) and `GoodSignal` in-process signals throw if any listener errors. The codebase defends the critical paths with `pcall` around every `Fire` (`CustomerService:_fireTicket`, `CustomerResolved:Fire`, `CustomerLeft:Fire`). Any new `Fire` on the serve/ticket path must be `pcall`-wrapped or one bad listener breaks serves for everyone. Related startup trap: `client/init.client.luau` indexes **every** module under `client/Modules/` for `PlayerAdded`/`PlayerRemoving` without a type check — a helper module must return a table (server side skips non-tables, client side does not).
2. **Tool state is attributes, but validity gates read names.** Recipes grade tools purely from attributes (`Item`, `Size`, `Syrup`, `Tapioca`, `Iced`, `Sugar`; `Served` = already handed over) via `OrderSpec.Match`, while station validity checks (`ToolNameValidityCheck`) read the tool's *Name*. A recipe that renames a tool (`RenameToolHolding`) must also write the matching attributes (`SetToolAttributes`), and every station must end with `SetToolAttributes` (givers pass attributes to `GiveTool`). Manual resets are the classic bug source here: the Sink "Wash Cup" branch had `Served`-retention, cup-size desync, and Clear-Cup demotion bugs precisely because the reset had to reproduce this state by hand (`SetToolAttributes`'s `ClearAttributes` path + `RenameToolHolding`'s size logic).
3. **No-yield windows on the serve path.** In `CustomerService:_onServeTriggered`, after the tip bonus is resolved there must be **no yield** between the guards (clocked in → distance → still waiting → assigned/rescue → `FindServeTools`) and the tool destroy, payout, `RecordTeamServe`. Same rule in `RealOrderService._onOrderPickedUp`. Inserting a yield there can consume a tool twice or pay twice. Deferred work (quests, toasts, dispatch) is `task.spawn`/`task.defer` for this reason.
   - Bonus trap for FTUE work: `CustomerService:_readServedCount(player)` returns `CustomerConfig.FIRST_SESSION_COUNT` (3) when profile data cannot be read. That fallback makes a player look *graduated* (no auto-grant, `OnboardingCompleted` can fire on serve #1). See FTUE_TRACE.md.

## Ignore These (save context)

- `.review/agent-workflow/archive/` — completed task packets. They are historical evidence (the FTUE-FIXES plan explains the Sink Washout rationale); read only if you need the "why", never treat them as current state.
- `.worktrees/` — other branches (`monetize-001`, `MOP-FLIP`) with duplicate/stale copies of `src`. Never read code from there; it is not this branch.
- `.claude/` — Claude Code's private folder. Other agents read/write nothing here.
- `.deepcode/.rv/`, `.deepcode/settings.json` — tooling state, not project docs.
- `docs/STYLE.md` is not stale, but only open it when doing UI work; `docs/SYSTEMS.md` + `CURRENT_STATE.md` cover the rest.

## Board & workflow (operational state)

- Board/ledger: `.review/agent-workflow/board.json`, `completed.ndjson`, `decisions.md`. These are local, gitignored operational state; recreate from "Board and ledger formats" in `docs/AI_AGENT_WORKFLOW.md` if missing.
- Task evidence lives at `.review/agent-workflow/tasks/<ID>/`; finished work is archived. Never put task docs in `docs/` or at `.review/` root.
- Jack approvals (never infer): failure screens/join blocks, publishing, uploads, economy prices/probabilities/rewards, destructive data migrations, secrets, scope widening. Core design guesses are `PENDING JACK` questions, never assumptions (DEC-008).
