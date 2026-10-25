# REVIVAL-001-M0.4 — Gauge runtime QA

- Role: Gauge (runtime QA). Date: 2026-10-13.
- Studio: `0bec4a01-246f-4fcf-b1b5-d37cfaf45e80` ("jacks project", place 89999123284040), Rojo live sync.
- Git HEAD: `92f61447ecd8ebb898fefb841261fabeb46b51cd` + uncommitted working tree (branch `uhweifh`).
- Place was not saved or published. No Edit-mode place edits. Play stopped at end (Studio in Edit mode).
- `TESTS_ENABLED` set to true for scenario 1 and then set back to false; `git diff --exit-code -- src/server/Tests/RunTests.server.luau` is clean.
- Scope cut by Prime partway through: scenarios 3–6 marked NOT RUN, blocked by the client Knit P0 below.

## Results

| # | Scenario | Result |
|---|----------|--------|
| 1 | TestEZ suite | PASS: 122 passed, 0 failed, 0 skipped |
| 2a | Clean boot, server | PASS with gaps noted below |
| 2b | Clean boot, client | **FAIL**: client Knit never starts, no HUD |
| 3 | Clock in/out | NOT RUN (blocked by P0); partial server evidence below |
| 4 | Make one boba | NOT RUN (blocked by P0) |
| 5 | Order round trip | NOT RUN (blocked by P0) |
| 6 | Two players | NOT RUN (blocked by P0) |

### 1. TestEZ: PASS
Steps: set `TESTS_ENABLED = true` locally. Checked that Rojo synced it with execute_luau (Edit): `ServerScriptService.Server.Tests.RunTests` Source contains `TESTS_ENABLED = true`, and its siblings are OrderService.spec, CurrencyService.spec and ShiftService.spec. Started Play, waited 15 s, then read the console.
- CurrencyService: 20/20 (TrySpendAsync: data unavailable, insufficient balance, invalid amount, invalid currency type, sufficient balance)
- OrderService: 92/92 (including Client.CreateOrder self-only, debounce, queue gating, clock-in claim gating, pick-up paths)
- ShiftService: 10/10
- Output: `[Tests] All 122 test(s) passed.` The expected `[CurrencyService] Invalid …` and `[OrderService] Rejected order …` warnings come from the negative cases. Log: `console-testez.txt`.
- After the run, Play was stopped, the flag was set back to false, and the Edit Source was checked to show `TESTS_ENABLED = false`.

### 2. Clean boot

**Server checks: PASS**
- `[Server] Knit started successfully.` is printed.
- `workspace.Assets.Kitchen` has 83 ProximityPrompts: Givers 58, Syrups 19, TrashCans 6. Of the 50 `Recipes.Items`, 49 have a model; the missing one is `Sink`, which is already known.
- 19 syrup dispensers spawned in `Kitchen.Syrups`. Each one has a prompt.
- `ReplicatedStorage.Networking` contains InventoryEvent (RemoteEvent), GetPurchases (RemoteFunction) and RedeemCode (RemoteFunction).
- The player has `ClockedIn=true` and is on Team `Baristas`. Teams = Baristas, Customers.
- `ReplicatedStorage.ModelStorage` exists.
- Gap (record only): 7 Giver models have no recipe and therefore no prompt. They are Fruits Freezer ×2, Restocking ×2, Salted Hot Chocolate Powder, Peppermint Hot Chocolate Powder and Oolong Tea Powder.

**Client checks: FAIL (P0)**
```
UI is not a valid member of Folder "SoundService.SFX"
Script 'Players.bongusbingis.PlayerScripts.Client.Modules.AppDialogs', Line 31
Requested module experienced an error while loading
Script 'ReplicatedStorage.Packages._Index.sleitnick_knit@1.7.0.knit.KnitClient', Line 227 - function AddControllersDeep
Script 'Players.bongusbingis.PlayerScripts.Client', Line 7
```
- `Knit.AddControllersDeep` throws, so `Knit.Start()` is never called. `[Client] Knit started successfully.` never prints.
- PlayerGui contains only Freecam and the UIArchive folder. No HUD ScreenGui exists. Screen capture `M04_Boot_1` shows the world with no HUD.
- In the place, `SoundService.SFX` contains only Kitchen, Music and SFX. There is no `UI` folder, and `SoundService.Music` is also absent, which `DataController.luau:14` waits for. AppDialogs.luau is unchanged from HEAD, so this is a gap between the code and the place, not a regression in this diff. It still blocks every client flow.

**Warnings and non-fatal output (source)**
1. `The experience doesn't have access permission to use asset id 13651538692/13651540778/13655528152/13655987384/13655988810`, and `Failed to load sound rbxassetid://…: User is not authorized`: engine asset permissions for 5 sound ids. These are place/asset permissions and also affect live servers if the ids are not shared.
2. `[BadgeService] - Not running BadgeService in Studio.` (BadgeService, expected)
3. `[profilestore]: Roblox API services available - data will be saved` (ProfileStore info). Studio Play writes to the real DataStore.
4. `[SpillService] Spills disabled; missing authored content: …Spills.Boba, …Tools.Mop, …Tools.MopBucket, …Sparkles` (known, expected)
5. Not emitted, because the client never booted: kitchen SFX, `BobaBalls`, OldScriptables.

Noted while reading code (not observed at runtime): `KitchenService/Actions/ToolNameValidityCheck.luau` has a debug `print(toolName, term:sub(2))` on every `#` term. The tapioca check is `"# Milk|#Tea"` (leading space), but the syrup step renames the tool to `Milk + <flavor> Syrup`, which has no space before "Milk". The tapioca step may therefore refuse a syrup-flavoured milk drink. This should be verified in scenario 4 once the client boots.

### 3. Clock in/out: NOT RUN (partial evidence)
There was no client controller or HUD to drive. Before Prime cut the scope, the raw Knit remote `ShiftService.RF.SetClockedIn` was invoked from the Client datamodel:
- `false` returned `Success=true "Clocked out."`. The attribute became false and the Team became Customers.
- An immediate `true` returned `"Please wait before switching again."`.
- `"yes"` returned `"Invalid request."`.
The kitchen-prompt refusal while clocked out was not verified: the character teleport fell under the map and navigation found no route.

### 4–6: NOT RUN
These are blocked by the client Knit P0. Driving the UI needs DialogController (cup size dialog), the Ordering UI and the HUD. Multi-client was not attempted.

## Captures
- `M04_Boot_1`: client view in Play, no HUD.

## Files
- `console-testez.txt`, `console-boot.txt`
