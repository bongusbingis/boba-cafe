RESULT: PASS (gate/build only; no Studio runtime — per task, no Play/TestEZ)

M3-STUBS: central Creator Hub product-ID stubs + shop wiring. No real IDs, no prices set.

Inventory (grep: PromptProductPurchase/PromptGamePassPurchase/GetProductInfo/
DeveloperProduct/ProductId/BOBA_PARTY/SkipHatch/SKIP_HATCH over src):
- src/server/Scripts/ProcessReceipt.server.luau — UNTOUCHED (read-only lane rule).
  Only MarketplaceService.ProcessReceipt site. SKIP_HATCH_PRODUCT_ID=1143554452
  (live); BOBA_PARTY_PRODUCT_ID nil with `if` gate (lines 33, 86-98, DEC-029 E18).
- src/shared/UI/Components/Core/Hud/BottomLeft.luau — UNTOUCHED. Only client
  PromptProductPurchase site (skip-hatch, line 356; hardcoded ID line 27).
- No BB-pack definitions, no capsule Robux paths, no GetProductInfo callers exist
  (CapsuleService is BobaBucks-only; GamepassUtil is game passes, out of scope).
- src/shared/UI/Pages/Shop/Currency.luau had mock BB rows (hardcoded prices, no
  OnPurchase → inert). Points rows are in-game currency, out of scope, untouched.

CHANGED (2 files; ProcessReceipt/ActivityScript never read-or-written beyond the
read-only ProcessReceipt inventory read above):
- NEW src/shared/Configuration/ProductIds.luau — single config module; all nil
  with JACK paste comments: BobaParty, BobaBucks Pack50/150/500/1000/5000,
  CapsuleRobux NametagCapsule1/10/50 (mirror BB sizes; no Robux capsule offers
  exist yet). Skip Hatch deliberately excluded (live, stays hardcoded).
- src/shared/UI/Pages/Shop/Currency.luau — BB rows built from ProductIds stubs;
  click prompts PromptProductPurchase only when ID non-nil (nil = inert, as
  today); price shown only from live GetProductInfoAsync (DEC-026), pcall-guarded,
  never hardcoded. Mock BB prices removed.

Nil-behavior preserved: all stubs nil → no prompt fires anywhere new; shop rows
render without price and clicks no-op; ProcessReceipt gate unchanged (Boba Party
unmapped → NotProcessedYet, as today). Filled-ID path assumed working per task;
no purchase simulated. No TestEZ/Studio run per task.

CHECKS: selene new=0 on both files (0 findings total; ProductIds baseline=empty,
Currency baseline=HEAD) | stylua --check PASS both | rojo build
default.project.json → %TEMP%/gate-build-m3-stubs.rbxl PASS (module included).
Full gate.sh not runnable: script is LF in git but CRLF in checkout, so
`wsl bash scripts/gate.sh` dies on line 9 (`set: -: invalid option`) before any
check — pre-existing checkout artifact, not caused here. Equivalent checks above
run with the same tool versions (selene 0.31.0, stylua 2.5.2, rojo 7.7.1).
See gate-output.txt.
