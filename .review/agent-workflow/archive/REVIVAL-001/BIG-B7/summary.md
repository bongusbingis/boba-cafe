# BIG-B7 evidence — station skill-moment pass (continued, not restarted)

Lane: Mason. Branch: uhweifh. All in-flight changes preserved (POUR_METER
config, SkillMoment markers, pure PourMeter logic, other lanes' dirty files).

## What was built (minimal end-to-end behind SKILL_MOMENTS_ENABLED)

- `src/server/Modules/KitchenService/PourMoments.luau` (new): server window
  manager. `MaybeOpen` fires `PourWindowOpened` with `PourMeter.ToView` after
  a successful pour-station run; the server owns the clock (`os.clock`).
  `ReportTap` grades via `PourMeter.Resolve` (latency allowance from config),
  consumes the window, and sets the held tool's `PerfectPours` attribute via
  `PourMeter.AddPerfect` (capped). `TipForTools` returns the flat tip via
  `PourMeter.TipFor` for the serve lane to add before it destroys tools.
  The meter unlocks on the first `CustomerService.CustomerResolved`
  `Kind == "Served"` (walkouts do not count), matching MIN_CUSTOMERS_SERVED.
- `InteractionRunner.luau`: optional `onSuccess` callback, fired guarded
  after a successful sequence (success path unchanged otherwise).
- `KitchenService/init.luau`: `PourWindowOpened` / `PourResolved` client
  signals, `ReportPourTap` / `GetPourTip` client-callable methods, runner
  wired to `PourMoments:MaybeOpen`.
- `src/client/Modules/KitchenController.luau`: imperative meter UI from
  Styles tokens only (GREEN track zone/button, GREEN_DEEP track,
  OFFWHITE marker, Fredoka TAP button, PromptButton-style radius/stroke).
  Marker animates with the shared `PourMeter.Position`; tap reports elapsed
  time; perfect resolves to a "Perfect pour!" toast; skip/miss hides silently.
- `src/server/Tests/PourMeter.spec.luau` (new): focused TestEZ spec for the
  pure logic (Position/InZone/NewWindow/EffectiveElapsed/Resolve/AddPerfect/
  TipFor). Spec expectations cross-checked with an independent Python oracle.
- `KitchenConfig.luau`: tuning values only, untouched (in-flight values kept).

## Out of scope (not touched)

OrderTicket/Hud/init/Recipes pages, RealOrderService, CafeRating*,
ProgressionService, CustomerConfig, `ActivityScript.server.luau`. The serve
payout itself stays with the serve lane: it calls `GetPourTip(tools)` before
destroying tools. Nothing committed or pushed.

## Verification

- `gate` on all 7 files: PASS (selene new=0 everywhere, stylua ok, rojo
  build ok). Full log: `gate-output.txt`.
- TestEZ spec: NOT RUN (DEC-019: no Play/TestEZ runs; Studio-only suite).

## B7-TIP-WIRE (2026-10-21, Mason, branch uhweifh)

Wired the pour tip into the NPC serve payout in
`src/server/Modules/CustomerService/init.luau` (`_onServeTriggered` ONLY;
no other file touched, nothing committed or pushed):

- Before the tool-destroy loop: guarded `pcall` read
  `Knit.GetService("KitchenService"):GetPourTip(tools)` into `pourTip`
  (0 on missing service, error, or non-number result; serve never breaks).
  Read sits before `tool:Destroy()` since `TipForTools` reads the tools'
  `PerfectPours` attributes. No yield added (pure call, same `Knit.GetService`
  pattern as the existing `PerkService` tip calls on this path).
- After the existing pass/pet tip block: `if pourTip > 0 then tip += pourTip;
  pay += pourTip end`, so the pour tip lands in the paid total
  (`CurrencyService:Modify`), the floating `+N` pay label, and the
  `CustomerResolved` `Tip` field that feeds the ShiftCard Tips line
  (`ShiftService:RecordCustomer`: `Pay += result.Pay`,
  `Tips += floor(result.Tip)`). Mirrors the existing tip/pay flow.
- B4-P1 hooks, `_sessionShifts`/PATIENCE code untouched.
  `ActivityScript.server.luau` never read, touched, staged, or committed.

Verification: `scripts/gate.sh` (wsl) on the file: selene new=0
(baseline[HEAD]=0 now=0), stylua=ok; rojo build ok to outside-repo
`/mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl`.
Full log appended to `gate-output.txt`. No Studio/Play/TestEZ runs.
