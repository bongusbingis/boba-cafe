# boba-cafe Development Conventions

## 1. Philosophy
**The four highest product priorities are monetization, engagement, retention, and concurrent player count (CCU).** These take precedence over code elegance, architectural purity, strict validation for its own sake, and implementation convenience. Judge product and system design by its effect on those four outcomes. Preserve the existing server-authority, ownership, purchase, and data-integrity contracts that make those outcomes sustainable.

**Keep players playing, even when a feature is degraded or broken.** Missing sounds, images, fonts, animations, cosmetic effects, and even feature errors should default to bounded waits, useful diagnostics (`warn` with the system name), isolated failures, and as much continued play as possible. Do not automatically substitute a failure screen or kick/deny a player because a check failed. Showing a failure screen or deliberately blocking a player from joining or playing requires Jack's explicit approval, including for critical errors. Agents must not infer that approval from permission to implement a feature or fix a bug. Test failure and timeout paths for continued play. Preserve purchase, ownership, server-authority, and data-integrity protections; continued play does not authorize granting purchases, corrupting saves, or accepting untrusted client input. (Ending a session when the profile cannot be loaded or its session is lost is a data-integrity protection, not a precedent for blocking on optional systems.)

**Simplicity over sophistication.** This codebase is maintained by one person. Agents must write simpler code, not more complicated code. Abstraction should reduce complexity, not add layers.
**Player-facing quality over code elegance.** The player experience is what matters. Implementation elegance behind the scenes is secondary.
**Pragmatism over purity.** It's acceptable to use approaches that might be considered "bad practice" if the "correct" alternative would waste significant tokens and effort while producing the same player-facing result.
**Don't over-engineer.** This is a Roblox game, not a massive production with a large staff. Code should be as simple as it can be while still working correctly.
**Reduce, don't expand.** The codebase needs refinement and simplification. When touching existing code, look for opportunities to simplify. Don't add complexity without justification. Do not mass-reformat or mass-convert files you are not otherwise changing.

## 2. Luau & Knit Patterns
- **Services and controllers**: Server features are Knit services (`Knit.CreateService { Name = ..., Client = { ... } }`) under `src/server/Modules/`; client features are Knit controllers (`Knit.CreateController`) under `src/client/Modules/`. `Knit.AddServicesDeep` / `AddControllersDeep` `require` every ModuleScript under those folders (helpers included), so a new service or controller needs no registry edit, and every helper placed there is loaded at startup and must be safe to require early. A helper under `src/client/Modules/` must return a table because `init.client.luau` indexes each result. A service that needs another resolves it with `Knit.GetService("Name")` at call time or in `KnitStart`, not at require time.
- **World content**: Instances authored in the place (`workspace.Assets`, `Ordering System`, `SharedStorage`, `SelectorModels`, `SoundService` groups) are resolved in `KnitStart` or at use time, never at require time, with `src/shared/Utility/WorldPath.luau` (`find`: nil if missing, no yield; `waitFor`: one shared deadline for the whole path) or a bounded `WaitForChild`. Never an unbounded wait or a direct index chain on content you do not own. When a path is missing, `warn` once with the system name and the exact path, and disable only that feature. Name the exact paths in `SYSTEMS.md` when you add a dependency.
- **Lifecycle**: Use `KnitInit` for setup that does not touch other services and `KnitStart` for anything that does. `src/server/init.server.luau` and `src/client/init.client.luau` call an optional `PlayerAdded(player)` / `PlayerRemoving(player)` method on every service/controller; use those instead of connecting to `Players` yourself. `DataService` is always torn down last on the server so other services can still read profile data in `PlayerRemoving`.
- **Client-exposed API**: Everything a client can call lives in the service's `Client` table. Treat every argument as untrusted (see Section 6).
- **Async**: Anything that yields or returns a Promise is named `*Async` (`GetDataAsync`, `GetRankAsync`). Promises come from `Packages.Promise`; always end a chain with `:catch(warn)` or handle the rejection. Use `task.spawn` / `task.delay` / `task.defer`, never the legacy `spawn` / `wait` / `delay`.
- **Section comments**: Files group their top-level code under `---> services`, `---> dependencies`, `---> types`, `---> constants`, `---> private`, `---> public`, `---> lifecycle` style headers. Match the file you are editing.
- **Type annotations**: Start new files with `--!strict` and `export type` the shapes other modules use. Existing files that are `--!nonstrict` or unannotated stay as they are unless you are already rewriting them.
- **Naming**: `PascalCase` for files, modules, services, controllers, and types; `camelCase` for local variables and local functions; `SCREAMING_SNAKE_CASE` for module-level constants; leading underscore for private service methods (`_handlePickUp`).
- **Formatting**: StyLua defaults (tabs) for new and edited code. Do not reformat untouched code to satisfy it.
- **Error handling**: Functions that can fail return `(boolean, string?)` for `(success, reason)` rather than throwing, and remote handlers that reply return `{ Success: boolean, Message: string }` as `RedeemCode`, `CreateOrder`, and `ShiftService.Client:SetClockedIn` do. Validate, `warn` once with the system name, and return early.
- **Signals and cleanup**: In-process signals use `Packages.GoodSignal`; connection and instance lifetimes use `Packages.Janitor`. Do not add another signal library or hand-rolled listener lists. Every `Connect` made for a player must be cleaned up in `PlayerRemoving`.

## 3. Player Data
- **One path in**: Read profiles only through `Knit.GetService("DataService"):GetDataAsync(player)`, which yields until the profile has loaded. Write replicated fields with the proxy's `:SetValue({ "Path", "To", "Field" }, value)`. Direct writes to `proxy.Data` change the saved table but do not replicate; use them only where the existing code already does so deliberately.
- **Template**: `src/shared/Configuration/ProfileTemplate.luau` is both the type and the default values; `Reconcile` fills in new fields for existing profiles. Adding a field is safe. Renaming, removing, or changing the meaning of a field needs a migration and Jack's approval. Changing `PROFILE_STORE_NAME` abandons every existing profile and is a destructive migration.
- **Currency and stats**: Change currency only through `CurrencyService:Modify` and counters only through `StatisticsService:IncrementStat` so the paired statistics stay correct.
- **Server-only data**: Anything that must never reach clients (promo codes, reward tables) lives under `src/server/` and is never required from `src/shared/`.

## 4. React & UI Patterns
- **Functional components**: UI components are plain functions returning React elements. Use the `local c = React.createElement` alias. Build containers with `Pane` (`src/shared/UI/Components/Pane.luau`) instead of hand-assembling Frames with UICorner/UIStroke/UIListLayout children.
- **Layout**: Position and size with scale (`UDim2.fromScale`) plus `AspectRatio` on `Pane`, so one component works on desktop and mobile. Check phone layouts: `ItemCard` branches on `UserInputService.TouchEnabled`, and `Pages/MobileOrder` is the phone-specific ordering page.
- **Hooks**: Custom hooks live in `src/shared/UI/Hooks/`, use the `use` prefix, and return bindings or small tables (`useClock`, `usePx`). Clean up connections in the effect's returned function.
- **Animation**: Use `ReactSpring` with the spring configs from `Styles.luau`; do not hand-roll tween loops.
- **Dialogs**: Server-initiated prompts go through `DialogService:CreateDialog(player, dialogType, props)`; `dialogType` must match a module in `src/shared/UI/Components/Dialogs/`. Toasts go through `DialogService:Notify`.
- **Stories**: Each reusable component or page has a `*.story.luau` in `src/shared/UI/Stories/` (a `function(target)` that renders into `target` and returns a cleanup function). Add or update a story with the component.
- **Visuals**: See `docs/STYLE.md`. Never invent colors, fonts, radii, or springs; import `src/shared/UI/Styles.luau`.

## 5. Testing
- **Framework**: TestEZ (`Packages.TestEZ`).
- **File naming**: Tests are named `*.spec.luau`.
- **Location**: Server specs live in `src/server/Tests/`, next to `RunTests.server.luau`.
- **Execution**: Studio only. `RunTests.server.luau` returns immediately unless `TESTS_ENABLED` is `true`; flip it locally, run a Play session, read the Output, and set it back to `false` before finishing. There is no headless runner.
- **Scope**: Prefer testing pure logic and service decisions (queueing, validation, clock-in checks, spending) with fakes over testing Roblox instances. Anything that needs the authored place (kitchen models, ordering screens) is verified in Studio and recorded as evidence.

## 6. Security & Server Authority
- **Never trust the client**: Check `typeof` of every remote argument, range-check numbers, verify the player's rank (`RankUtil`) and ownership (inventory, gamepass) on the server, and ignore requests that fail with a quiet early return or a `{ Success = false }` reply.
- **Rate-limit state-changing remotes**: Use a per-`UserId` debounce table cleared in `PlayerRemoving` (see `ShiftService`, `PromoCodes`, `OrderService`).
- **Purchases**: `ProcessReceipt` is idempotent on `PurchaseId` (recorded in `ProcessedReceipts`), grants only after the effect is applied (a product action returns `true` only then), confirms the save before `PurchaseGranted`, and returns `NotProcessedYet` when the player or data is unavailable, the product is unmapped, or the action cannot apply (Skip Hatch with no hatch pending, DEC-006). Never answer `PurchaseGranted` for something that was not delivered. Spend through `CurrencyService:TrySpendAsync`, not `Modify`.
- **Client-built data**: When a client sends a request that becomes server state (orders), send only the choice and rebuild the object on the server from server-owned definitions. Validate every key and type, and reject unknown keys. Client callers wrap the Knit call in `pcall(... :expect())` with an in-flight guard so a failure or slow reply cannot lock the UI.
- **Shift, not rank**: Barista actions (kitchen stations, claiming and queueing for orders, cleaning spills) check `ShiftService:IsClockedIn` on the server. Group rank (`RankUtil`) does not gate gameplay and must not be used to block joining or playing (DEC-002, DEC-004). Remaining uses are display, badges, and `MinRank` settings. Client-side hiding is presentation only.

## 7. Configuration
- **Shared tuning**: `src/shared/Configuration/` holds constants and definitions (`KitchenConfig`, `Spills`, `CapsuleConfig`, `Gamepasses`, `InventoryItemDefinitions/`) as plain Luau tables with no logic beyond building the table.
- **Server-only**: `src/server/Configuration/` (promo codes).
- **Catalog data**: Item, capsule, tier, gamepass, and promo definitions are product data. Do not change IDs, rarities, odds, durations, or rewards without Jack's approval.

## 8. Build & Tooling
- **Rojo**: File syncing via `default.project.json` (README notes Rojo 7.4.4). `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`, `src/client` → `StarterPlayerScripts.Client`.
- **Wally**: Package management (`wally.toml`). `Packages/` and `ServerPackages/` are generated and gitignored; never edit them.
- **StyLua**: Formatting.
- **Selene**: Linting (`selene.toml`, `std = "roblox"`).
- **Place file**: The authored world is saved in the Roblox place, not in this repository. Open the built `.rbxlx` (gitignored locally) or the live place, then `rojo serve`.

## 9. File Organization
| Type | Location |
|---|---|
| New server feature | `src/server/Modules/<Name>Service.luau` (or `<Name>Service/init.luau` with helpers beside it) |
| New client feature | `src/client/Modules/<Name>Controller.luau` |
| Server-run scripts with no API | `src/server/Scripts/*.server.luau` |
| Client-run scripts with no API | `src/client/Scripts/*.client.luau` |
| Code used by both sides | `src/shared/<Domain>/` (Inventory, Kitchen, Ordering, Pets, Utility) |
| Tunable data and definitions | `src/shared/Configuration/` (server-only: `src/server/Configuration/`) |
| UI pages / components / hooks | `src/shared/UI/Pages/`, `Components/`, `Hooks/` |
| UI stories | `src/shared/UI/Stories/` |
| Tests | `src/server/Tests/` |
| Task evidence | `.review/agent-workflow/tasks/<ID>/` |

## 10. Things NOT To Do
- **DON'T** invent new visual palettes, fonts, or radii — use `Styles.luau` and `docs/STYLE.md`.
- **DON'T** create task-specific docs in `docs/`. Put task evidence and docs in `.review/agent-workflow/tasks/<ID>/`; finished tasks move to `.review/agent-workflow/archive/<ID>/` (see "Artifact layout" in `AI_AGENT_WORKFLOW.md`).
- **DON'T** touch profile data except through `DataService`, `CurrencyService`, and the inventory API.
- **DON'T** add packages without updating `wally.toml`, and don't hand-edit `wally.lock`, `Packages/`, or `ServerPackages/`.
- **DON'T** bypass server authority for currency, inventory, shift state, orders, or purchases.
- **DON'T** gate gameplay on group rank or add a join check; use `ShiftService` for barista actions.
- **DON'T** require server-only modules from shared or client code.
- **DON'T** make optional systems (audio, pets, cosmetics, notifications) able to stop a player from joining or ordering.
- **DON'T** leave `TESTS_ENABLED = true` or any new Studio-only shortcut (like `STUDIO_GRANT_ALL_ITEMS` in `src/server/init.server.luau`) switched on in a finished change.
