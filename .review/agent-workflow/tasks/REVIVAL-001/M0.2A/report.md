# REVIVAL-001-M0.2A report (Mason)

Base commit: 92f6144. Nothing staged or committed. `wally install` not run; Packages and wally.lock untouched.

## Changed files
- `src/server/Scripts/ProcessReceipt.server.luau` (F4, F5)
- `src/server/Scripts/PromoCodes.server.luau` (F4)
- `src/server/Scripts/RankClaiming.server.luau` (deleted, F11)
- `src/server/Modules/RankingService.luau` (deleted, F11)
- `src/server/Modules/CurrencyService.luau` (F6)
- `src/server/Tests/CurrencyService.spec.luau` (new, F6)
- `src/server/Modules/SpillService/init.luau`, `Spill.luau` (F7, F8)
- `src/client/Modules/SpillController.lua` (F8; file is CRLF, kept CRLF)
- `src/shared/Configuration/Spills.luau` (SpawnInterval = 30, tuning value, not a reward)
- `src/shared/Configuration/SettingsConfig.luau` (ClaimRank removed, F11)
- `src/shared/Configuration/ProfileTemplate.luau` (`ProcessedReceipts = {}`)
- `wally.toml` (F9: removed `sleitnick/table-util`; kept `bongusbingis/table-utility@1.0.0`)

## Decisions
- F4: remotes `GetPurchases` / `RedeemCode` are found or created under `ReplicatedStorage.Networking` (folder created if absent) by a per-script helper with no yields. `MarketplaceService.ProcessReceipt` is assigned before the first `WaitForChild`; it answers `NotProcessedYet` until Knit has started, then delegates to the real handler.
- F5: unmapped ProductId warns loudly and returns `NotProcessedYet`. Idempotency: `ProcessedReceipts[PurchaseId] = os.time()` in the profile, capped at 200 (oldest pruned). Flow: load profile (30 s timeout) -> already recorded? `PurchaseGranted` -> run grant -> record (no yield between) -> spawn the DataStore history write in a pcall (cannot affect the decision) -> `PurchaseGranted`. An in-flight set blocks re-entrant calls. The third element of ProductActionMap entries (includePlayerData) was dropped because data is now always loaded.
- F6: `CurrencyService:TrySpendAsync(player, type, amount): (boolean, string?)`. The `Async` suffix is because it yields while data loads. Reasons: InvalidCurrency, InvalidAmount, NoData, InsufficientFunds. Rejects non-integer, NaN, infinity and non-positive amounts. The balance check and deduction have no yield between them. BobaBucks spends increment `BobaBucksSpent`. `Modify` is unchanged in behaviour. A `_getService` hook was added so specs can fake services.
- F7/F8: the world is resolved in `KnitStart` with a 10 s total budget. If `workspace.Assets.Spills(.Areas)`, `SharedStorage.Spills.Spills.Boba`, `.Tools.Mop`, `.Tools.MopBucket` or `.Sparkles` is missing, SpillService warns once and stays disabled. Three consecutive spawn failures also disable it. GlobalMulti, BoostActive and the boost timer are gone: cleanliness now saturates at 100 and the reward is left for the later Cafe Rating work. The client label at 100% now reads `100%` (was "Boost Active!"). `Knit.Services.PromptService` is replaced by `DialogService:Notify`, `Knit.Shared.ItemFader` by the existing `Shared.Utility.ItemFader`. `Spill.new` cleans up and rethrows on a build error. The cleaning interaction is pcall-wrapped and unlocks the player on failure. The client no longer indexes the world at require time or in KnitInit; the removed `Knit.Controllers.SetCoreAndControls` is replaced by a PlayerModule controls toggle.
- F11: ClaimRank settings removed. The "Game Passes" category stays with an empty Settings list; `Settings.luau` skips categories with no visible settings (`#visibleSettings == 0 -> continue`), so it still works.

## Gates
Tool binaries: the `selene`/`stylua` rokit shims hang or refuse without a project toolchain, so the binaries in `~/.rokit/tool-storage` were called directly (selene 0.31.0, stylua 2.5.2, rojo 7.7.0).
Counts are selene warnings and stylua diff lines (baseline = HEAD, now):

| file | selene base -> now | stylua base -> now |
|---|---|---|
| ProcessReceipt | 0 -> 0 | 139 -> 0 (file reformatted) |
| PromoCodes | 1 warn -> 1 | 214 -> 214 |
| CurrencyService | 2 warn -> 0 | 50 -> 0 |
| SpillService/init | 0 -> 0 | 2 -> 0 |
| SpillService/Spill | 2 warn -> 0 | 19 -> 0 |
| SpillController (LF-normalised for comparison) | 0 -> 0 | 51 -> 51 |
| Spills | 0 -> 0 | 2 -> 0 |
| SettingsConfig | 0 -> 0 | 80 -> 30 |
| ProfileTemplate | 0 -> 0 | 178 -> 178 |
| CurrencyService.spec (new) | 0 | 0 |

- `rojo build default.project.json -o /private/tmp/claude-501/m02a.rbxlx`: succeeded.
- TestEZ: NOT run (Studio only).

## Unverified
- Nothing was run in Studio: ProcessReceipt registration, the remotes resolving on clients, the spill degrade paths, and the TestEZ spec (written to need no authored place) are all unexercised.
- `SharedStorage.Spills.Spills.Boba`, `Tools.*` and `Sparkles` do not exist in the place. The names Spill.luau uses for model internals (`Liquid`, `MoppingAnim`, `SignStartPosition`, `TripRegion`...) cannot be checked from the repo.
- The stylua findings still left in PromoCodes, ProfileTemplate, SettingsConfig and SpillController are baseline findings I did not format.

## Risks and notes for Prime
- Durability: `PurchaseGranted` is returned once the grant and receipt are in the in-memory profile, but ProfileStore saves them on its autosave period (300 s) or at session end, not immediately. A server crash in that window loses both, and Roblox will not re-send the receipt. Closing this needs `profile:Save()`, but DataService is read-only for this task. Suggest a follow-up `DataService:SaveAsync(player)`.
- `Packages/_Index 2` and `ServerPackages/_Index 2` are empty directories; left untouched.
- `wally.lock` already lists only `bongusbingis/table-utility`; `Random` and `Shuffle` exist in that package.
- Callers of the new spend API should use `TrySpendAsync`, not `TrySpend`.
- PromoCodes and RankClaiming (now deleted) called `DialogService:Notify(player, { Text = ... })`, which does not match its `{Title, Description, Image}` signature. PromoCodes still does; it is outside this write scope.
- Docs (ARCHITECTURE.md, SYSTEMS.md, CONVENTIONS.md) still mention RankClaiming, ClaimRank and RankingService; Prime should update them.
- A spill that fails placement still calls `Destroy`, which credits cleanliness; left as is (not redesigning spills).
- `SpawnInterval = 30` is my placeholder; Forge or Jack may want to tune it.
