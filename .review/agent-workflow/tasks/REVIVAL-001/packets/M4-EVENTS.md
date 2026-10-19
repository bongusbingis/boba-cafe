# M4-EVENTS: Server Events & Rank Hosting
Model: sonnet / spark   Studio: no   Depends on: none   Size: M

## Goal
Implement the scheduled and staff-hosted Server Events system (revival-plan §4.7, DEC-032):
- Support 3 distinct 10-minute server events:
  1. `RushHour`: 2x NPC pacing and tip multiplier (`workspace:SetAttribute("RushHour", true)`).
  2. `KarenRush`: Frequent high-stakes Karens with 3x rewards (`workspace:SetAttribute("KarenRush", true)`).
  3. `TreasureFrenzy`: Fast chest respawns (15s) and increased chest capacity (`workspace:SetAttribute("TreasureFrenzy", true)`).
- Staff Hosting: Staff members with group rank >= 10 (or admins) can trigger an event with a 30-minute server-wide cooldown.
- Automated Scheduling: Triggers an automated event every 60 minutes if no event is currently running.
- Player notifications via `DialogService:Notify`.
- Connect event attributes to `CustomerService/Rules.luau` and `TreasureHuntService.luau`.

## Read (only these)
- `docs/AI_AGENT_WORKFLOW.md`
- `docs/CONVENTIONS.md`
- `.review/agent-workflow/decisions.md` (DEC-032)
- `src/server/Modules/DialogService.luau`
- `src/server/Modules/CustomerService/Rules.luau` (variant selection)
- `src/server/Modules/TreasureHuntService.luau` (spawn timing)
- `src/shared/Utility/RankUtil.luau`

## Write scope
- `src/shared/Configuration/EventConfig.luau` (new)
- `src/server/Modules/EventService.luau` (new)
- `src/server/Tests/EventService.spec.luau` (new)
- `src/server/Modules/CustomerService/Rules.luau` (check workspace KarenRush attribute)
- `src/server/Modules/TreasureHuntService.luau` (check workspace TreasureFrenzy attribute)
- `.review/agent-workflow/tasks/REVIVAL-001/M4-EVENTS/evidence.md` (new)

## Steps
1. Create `src/shared/Configuration/EventConfig.luau`:
   - `EVENT_DURATION_SECONDS = 600` (10 minutes)
   - `HOST_COOLDOWN_SECONDS = 1800` (30 minutes between hosted events)
   - `AUTO_EVENT_INTERVAL_SECONDS = 3600` (every 60 minutes)
   - `MIN_STAFF_RANK = 10`
   - `EVENTS`:
     - `RushHour`: `{ Name = "Rush Hour", Attribute = "RushHour", Description = "2x Customer Pacing & Tips!" }`
     - `KarenRush`: `{ Name = "Karen Day", Attribute = "KarenRush", Description = "Impatient Karens have arrived for 3x Tips!" }`
     - `TreasureFrenzy`: `{ Name = "Treasure Frenzy", Attribute = "TreasureFrenzy", Description = "Treasure chests are respawning rapidly!" }`
2. Create `src/server/Modules/EventService.luau`:
   - Knit service named `"EventService"`.
   - `StartEvent(eventName: string, hostPlayer: Player?): (boolean, string?)`:
     - Validates no active event is running.
     - If `hostPlayer` provided, validates `RankUtil:GetRankAsync(hostPlayer) >= EventConfig.MIN_STAFF_RANK` and checks server cooldown.
     - Sets active event, end time, and workspace attribute `workspace:SetAttribute(eventDef.Attribute, true)`.
     - Broadcasts notification via `DialogService:Notify` to all players (naming the host if staff-hosted).
     - Countdown task clears attribute and sets cooldown end upon expiration.
   - `GetActiveEvent(): { EventName: string?, TimeRemaining: number, HostCooldownRemaining: number }`
   - Client functions: `StartEvent` and `GetActiveEvent`.
3. Wire hooks:
   - In `CustomerService/Rules.luau`: when `workspace:GetAttribute("KarenRush") == true`, override Karen variant chance to 0.50 and min level to 1.
   - In `TreasureHuntService.luau`: when `workspace:GetAttribute("TreasureFrenzy") == true`, scale respawn delay to 15s and max chests to 8.
4. Create `src/server/Tests/EventService.spec.luau`:
   - Tests event start, duration expiration, overlap rejection, and staff rank validation.
5. Run WSL gate and verify clean output.

## Done when
- `EventConfig.luau` defines the 3 events and duration/cooldown limits.
- `EventService.luau` starts and manages events, sets workspace attributes, and announces start/end.
- Hooked services react to event attributes.
- `EventService.spec.luau` passes.
- WSL gate check passes cleanly.

## Checks to run
- `. .review/agent-workflow/tools/wsl/env.sh && gate src/shared/Configuration/EventConfig.luau src/server/Modules/EventService.luau src/server/Tests/EventService.spec.luau src/server/Modules/CustomerService/Rules.luau src/server/Modules/TreasureHuntService.luau`

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/M4-EVENTS/evidence.md`
