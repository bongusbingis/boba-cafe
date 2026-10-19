RESULT: PASS
Files changed:
- src/shared/Configuration/EventConfig.luau
- src/server/Modules/EventService.luau
- src/server/Tests/EventService.spec.luau
- src/server/Modules/CustomerService/Rules.luau
- src/server/Modules/TreasureHuntService.luau

Gate check output:
```
PASS  src/shared/Configuration/EventConfig.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/EventService.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Tests/EventService.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/CustomerService/Rules.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/TreasureHuntService.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

Notes on behavior:
- `EventConfig.luau`: Configures EVENT_DURATION_SECONDS (600), HOST_COOLDOWN_SECONDS (1800), AUTO_EVENT_INTERVAL_SECONDS (3600), and MIN_STAFF_RANK (10). Defines the 3 core events: `RushHour` (Attribute: "RushHour", 2x Customer pacing & tips), `KarenRush` (Attribute: "KarenRush", Impatient Karens arrive for 3x tips), and `TreasureFrenzy` (Attribute: "TreasureFrenzy", Rapid chest respawns & higher capacity).
- `EventService.luau`: Knit Service providing `StartEvent(eventName, hostPlayer?, durationOverride?)`, `GetActiveEvent()`, `EndActiveEvent()`, and `TriggerRandomEvent()`. Validates that no event is already running, verifies staff rank >= 10 via `RankUtil:GetRankAsync` (or `IsAdmin` attribute) and checks server cooldown for staff-hosted events, publishes the active event attribute to Workspace, announces start and end via `DialogService:Notify` to all players, fires client signals `EventStarted` and `EventEnded`, schedules event expiration task to clear attribute and activate the 30-minute host cooldown upon completion, exposes `StartEvent` and `GetActiveEvent` to clients, and runs an automated event loop in `KnitStart` every 60 minutes.
- `CustomerService/Rules.luau`: Hooked `PickVariant` to check `Workspace:GetAttribute("KarenRush") == true`. When active, overrides Karen variant chance to 0.50 and minimum barista level to 1, while preserving standard variant logic when the event is inactive.
- `TreasureHuntService.luau`: Hooked dynamic chest scaling when `Workspace:GetAttribute("TreasureFrenzy") == true`, scaling max chests from 5 to 8 and respawn delay from 90s to 15s. Added an attribute change listener in `KnitStart` to immediately spawn chests up to the elevated capacity when Treasure Frenzy triggers.
- `EventService.spec.luau`: TestEZ unit tests covering configuration integrity, automated and staff event starts, overlap rejection, staff rank validation (rank < 10 rejection, rank >= 10 and admin acceptance), host cooldown enforcement, duration countdown expiration, client functions, and event attribute hooks in `CustomerService/Rules` and `TreasureHuntService`.
