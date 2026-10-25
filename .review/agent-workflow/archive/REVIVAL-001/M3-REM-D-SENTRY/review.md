VERDICT: PASS-WITH-P3

# M3-REM-D Sentry review (Double Storage)
Scope: uncommitted diff of CapsuleService, PerkService, PerkService.spec, Perks, InventoryServer, Utility, plus InventoryLimit.spec (read whole). Static, read-only. No P1/P2.

## Findings

### P3-1 Failed pass lookup pins the multiplier at 1 for the session
- src/shared/Utility/GamepassUtil.luau:96-108 (existing) with PerkService.luau:89-95. If UserOwnsGamePassAsync fails 3 retries, the cache holds a resolved `false` for the session, so RefreshStorageMultiplier stores 1 for a real owner until rejoin. Fails closed (under-grant only), consistent with other pass perks.

### P3-2 Possible one-entry leak if the refresh lands inside the PlayerRemoving window
- PerkService.luau:91 / :114. Player.Parent is still Players while PlayerRemoving hooks run, so an andThen refresh landing after PerkService:PlayerRemoving but before reparent re-creates `_storageMultiplier[player]`. Memory only: the key is the old Player instance, a rejoin is a new instance, nothing is granted. Window is a single frame at most.

### P3-3 Insert's require-in-pcall is fail-closed but not strictly non-yielding on a cold module
- InventoryServer.luau:246-249. If Insert ran before init.server's AddServicesDeep loaded PerkService, `require` would run the module (it requires Knit/GamepassUtil with WaitForChild) inside the count-then-insert span. In practice every Insert needs a loaded profile, which is after services load, so the module is cached and the call is a table read. A failure leaves multiplier 1 (assignment is inside the pcall after the call returns). No fix required.

## Checks
1. Over-grant: PASS. Multiplier comes only from PerkService._storageMultiplier, written solely by RefreshStorageMultiplier from HasPerk(InventoryX2), which resolves only via PassCatalog 14067346 and server-side GamepassUtil. No remote or client input reaches it. Default is 1 until resolved (fails closed). PlayerRemoving clears the entry; the Parent-nil guard stops a departed player being re-added. Rejoin gets a new Player key so a stale entry grants nothing. GamepassUtil.GrantPassToCache has no callers. Utility ignores non-number or <1 multipliers and floors the product.
2. No-yield spans: PASS. storageLimit does Knit.GetService (sync on a started server, pcall'd), a table read and a Utility lookup. All five CapsuleService sites evaluate it after the count loop with no yield before Insert/TrySpend; the old code did the same require per call. InventoryServer:Insert has no yield added. pcall failure leaves multiplier at 1 (fail closed).
3. Equipped / over-limit: PASS. InventoryServer.luau:178 still calls GetInventoryLimit("Equipped", type) with no multiplier, and Utility never scales Equipped. Nothing deletes items; `>=` checks only refuse additions, so Q-D2=A holds. Pending hatches still get nil from Insert and keep RewardInsertFailed as before.
4. CapsuleService: PASS. grep finds no remaining InventoryLimits reference in the file or any non-test src outside Utility; all five sites (Capsules x4, Nametags x1) use storageLimit with unchanged operators and returns. Non-pass players get multiplier 1, so the limit is 10 live / 200 Studio as before (math.floor(n*1) = n).
5. Serve path: PASS. git status shows no change to CustomerService or RealOrderService; no yield was added to any serve span.
6. Specs: PASS on reading. PerkService cases use Parent = {} / nil stubs matching the guard and `service._hasPass` seam via ownedPasses; PlayerRemoving clears the entry; the 701 case relies on no prior refresh for a fresh table key. InventoryLimit.spec matches Utility (Storage x2 for all four types, Equipped ignored, 0.5/0/"2" ignored). Utility.luau also carries cosmetic paren removals only.
