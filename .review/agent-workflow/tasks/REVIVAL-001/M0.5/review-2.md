# REVIVAL-001-M0.5 — Sentry re-review

- **Source:** HEAD `92f6144` + uncommitted working tree as of review. M0.5 delta from `M0.5/diff-m05-only.patch`, plus new `src/shared/Utility/WorldPath.luau`. Checked against `M0.4/review.md` and `M0.5/findings-map.txt`.
- **Mode:** read-only. No Studio. M0.5 TestEZ and Play evidence are not in the folder yet.

## Verdict: **APPROVE-WITH-FIXES**

All P0/P1 items are fixed in source. No new P0/P1. Approval is conditional on Gauge re-running TestEZ and a separate 2-player Play session (TESTS_ENABLED=false). That run must show client Knit starting, which proves #1 at runtime, and must show the new CreateOrder specs passing.

## Verification of M0.4 P0/P1

| # | Status | Evidence |
|---|---|---|
| 1 P0 | Fixed (source) | `AppDialogs`/`ActionPrompt` look up `SFX.UI`, then `UISounds`, through `WorldPath.find` at play time. DataController has no require-time audio lookup any more. `SettingsConfig.setGroupVolume` only writes Volume on a SoundGroup; in the captured place `SFX` is a Folder, so that toggle warns once and is skipped. No other require-time `SFX` lookup remains in `src`. |
| 2 P1 | Fixed | Both UIs call `CreateOrder(...):expect()` inside a pcall on a spawned thread. `isSubmitting` is cleared after the await. Both UIs send `{Category, Item, CustomInfo}` with `FoodTable` keys (Ordering `:180,233`, MobileOrder `:204`). |
| 3 P1 | Fixed | `buildOrderItem` (`OrderService.luau` ~`:139-185`) does three things. (a) `DefaultInfo` is always the server Menu definition. (b) `Select` values must be in the Menu array, `RequiredSelection` values must be keys of the Menu dict, and `Options` must be booleans with Menu defaults. (c) Unknown keys are rejected. So every string `_updateStaffScreens` and `_updateStatusScreens` concatenates is server-defined, and every `Select`/`RequiredSelection` key has a string value. No client value reaches SurfaceGui text, and the nil-concatenation crash is gone. The shapes match `Menu.luau` (`Select` = arrays, `RequiredSelection` = dicts). |
| 4 P1 | Fixed | Spill.luau calls `Knit.GetService` on use; the OnStart locals are removed. `KnitServer.GetService` only asserts `started`, which Knit sets at `KnitServer.lua:389` before KnitStart runs. |
| 5 P1 | Fixed | The `Recovered` flag stops the delayed disable from running after controls are back on. The `IsPlaying` wait is capped at 5 s, and the nil-animation path re-enables immediately. |

The P2/P3 fixes also hold:
- **#6:** the cleaning animation load wait is capped at 3 s and then errors, so recovery runs.
- **#9:** the spec snapshots every field it reassigns, all 11 service fields plus 5 Client fields; I grepped every `service.X =` assignment to check. It restores them with rawset in `afterAll`.
- **#16:** MobileOrder has its in-flight guard.
- **WorldPath:** `waitFor` uses one deadline for the whole path. Once the budget is spent it still does `FindFirstChild` and never waits, and a negative budget is safe. SpillService and SpillController keep their shared 10 s budget by passing `Deadline - os.clock()`. The KitchenService, KitchenController and TopBar waits shrink from up to 2× their timeout to 1×, which is intended.

## New or remaining findings

| Sev | File:line | Issue | Fix |
|---|---|---|---|
| P2 (existing, newly found) | `src/shared/Utility/Animator.luau:61` | `LoadAnimation` returns `setmetatable(AnimationManager.Prototype, …)`, so every proxy is the **same table** and points at the most recently loaded track. With two concurrent cleaners, `Length`, `Stop` and Janitor `"destroy"` act on the other player's track, including the new #6 timeout path. | `setmetatable({}, { __index = function(_, k) local p = AnimationManager.Prototype[k]; if p ~= nil then return p end … })`. Also remove the debug `print` at `:56`. |
| P3 | `OrderService.luau` `getFoodTable` + `Menu.luau:2-4,379` | Menu does an unbounded `WaitForChild("SelectorModels")` and indexes `Models["Cup"]` / `Models["Pastry"]` directly. If any of these is missing, the first CreateOrder either hangs, so the client's `:expect()` never returns and `isSubmitting` stays stuck, or ordering is disabled for the life of the server. Low risk: SelectorModels exists per the recon. | Make the Menu lookups use `FindFirstChild` (lease outside M0.5). |
| P3 | `OrderService.luau:846-849` | Rejected orders set no debounce, so a client can flood the server log with `warn`s. | Debounce on rejection too, or warn once per player. |
| Tracked | #7, #8, #10–#15, #17 (remotes, spec trim), #18 | Deferred as listed in `findings-map.txt`. These are acceptable for M0 only if they are opened as board tasks. #10 (receipt runtime evidence) and #11 (Jack decision on Skip Hatch) must close before release. | Prime |

## Not verified
- Runtime behaviour of every fix. No M0.5 Studio console was present.
- The lint and rojo results are Mason's (`lint.txt`, `rojo-build.txt`). They show no new findings in the post-patch rows, and I did not re-run them.
