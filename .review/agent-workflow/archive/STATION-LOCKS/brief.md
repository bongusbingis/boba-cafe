# STATION-LOCKS — SCRAPPED per Jack (session 2026-10-22)

Client-side locked-station billboards were built, gated clean (Selene/StyLua/rojo),
then removed at Jack's request: kitchen stays free access, no lock UI.

Removed files (all added this session, no other code referenced them):
- src/shared/Kitchen/StationUnlocks.luau
- src/server/Tests/StationUnlocks.spec.luau
- src/client/Modules/StationLockController.luau

Notes for a possible revival:
- Rojo syncs to the "jacks project" place, NOT "Boba Cafe 🍵" — test there.
- A controller that arrives mid-play never loads (Knit runs at startup);
  needs a fresh F5 after sync.
- Mapping design (pool -> OrderSpec.Steps -> step.Station, plus flavor-suffix
  and option overrides) is documented in the session transcript.
