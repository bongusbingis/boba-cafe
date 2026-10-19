RESULT: PASS

# REVIVAL-001-S3 - what `boba-v4.rbxl` contains (Scout, read-only)

Task: REVIVAL-001-S3. Branch uhweifh, HEAD cbf5271.
Source: `main:boba-v4.rbxl`, blob `5eaf67185944e985ea5429173de50158031d02ed` (8,207,977 bytes). The only commit that touched it on main is `a476819` ("commit", bongusbingis, 2026-10-12).
Labels: **[src]** = read from v4 script source or place tree. **[inf]** = inferred. **[repo]** = read from files in this repo.

## Commands used
All scratch is under `/mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/s3/` (= `$TMPDIR/s3`). Nothing was written into the repo except this file.
- `. .../scratchpad/env.sh`
- `git show main:boba-v4.rbxl`, `main:tools/extract.luau` and `main:tools/tree.luau`, saved into `$TMPDIR/s3`
- `lune run extract.luau boba-v4.rbxl src` gave 623 scripts (3.7 MB), listed in `src/_MANIFEST.txt`
- `lune run tree.luau boba-v4.rbxl 4` gave `tree4.txt` (27k lines)
- Three small helper scripts I wrote in the scratch dir (not in the repo): `find.luau` (search names, print path and position), `kids.luau` (list children with attributes and position), `anim.luau` (list Animation and Sound instances)
- `grep` over the extracted sources, and `git log` / `git ls-tree` on main

**Limits.**
- lune 0.10.5 cannot read Content properties, so every `AnimationId` and `SoundId` read as unreadable. Asset IDs of instances are UNVERIFIED. Only IDs written in script source (gamepass IDs, shirt and pants IDs) are known.
- Part positions are first-BasePart world positions, rounded.
- I did not inspect the live Studio place. "Also in dev place" below means only what the repo or the S1 memo says [repo].
- `current-baseplate-build.rbxl` (blob b29c4a9) is also on main. I did not open it, so I can't say whether it is the dev place.

## What v4 is
- The `main` branch has no document describing v4. README is the Rojo stub.
- v4 looks like the **shipped live game** [inf]. Evidence [src]: real group IDs (3174578, 35512665); real gamepass and product IDs (Unlimited Stock 43707849, Water Pack 219651161, ...); `AntiLeak.client` guards `game.GameId == 718328620`; Knit services with DataStore leaderboards, tip jars, MR/HR ranks and an ad system; script headers dated June 2025.
- It is not a rescript: it is the old Knit codebase with a full map (19 registers, 34 seating groups, docks, VIP, pool).
- `old-v3.rbxl` (blob 683580b, 3.7 MB) also exists on main. It was not extracted.
- Its map is far larger than a slice. The kitchen sits around z=-200..-240 and the player spawns around z=+157..+186. The repo's `src/` is a ground-up rewrite (Rojo, `src/server/Modules`), so the v4 services are not in the repo [repo].

## v4 services (as asked in step 4)

### CustomerService (`ServerScriptService/Server/Services/CustomerService` + child `Customer`, Knit) [src]
- **Model.** The NPC belongs to the cashier, not to a barista. A player with the Cashier rank claims one of 19 registers (`Workspace.Assets.OrderingSystem.Registers/1..19`) and presses a request button. `Client:RequestCustomer` then calls `_SummonNpc`. At most one NPC per cashier (`Customers[Player]`). It is blocked if another player stands within 3 studs of the register customer zone, or when `TotalSpawns >= MaxCapacity` (25).
- **Lifecycle.**
  1. `Customer.new` clones `ReplicatedStorage.SharedStorage.NPCStorage.Rig`.
  2. It picks a `HumanoidDescription` at random from `NPCStorage.Characters`. 10% of NPCs are "Karen" (`NPCStorage.Special.Karen`).
  3. The NPC spawns at `Workspace.Assets.Customers.SpawnLocation` with a random +/-10 offset, fades in over 1.45 s, and walks with SimplePath (Water and Danger path costs set to infinity) to the register's generated `NpcZone`.
  4. On arrival it plays `Wave`, then says "Greeting" with item 1 of its order. The NPC is built with 1-3 items, picked at random from `ItemData.Categories`.
  5. The cashier clicks through the order. The NPC speaks the next "Followup" line for each item. This is chat-line dialogue, with no bubble UI.
  6. The cashier submits the order in the POS (`OrderService.Client:SendNonPlayer`). `CheckOrder` counts matching items. After 3 wrong submits (`MaxAttempts`) the NPC plays `Confused`, says a "Leaving" line and is destroyed.
  7. On a correct submit, the NPC says "WorkerAction" and walks to `Customers.WaitingArea` (random +/-7). It repeats a "Waiting" line every 40 s.
  8. A barista later finishes the order (see OrderService). `OrderCompleted` then makes the NPC reserve a random free `Seat` in `Workspace.Assets.Seating`, walk to it, sit, and play the `<GroupName>Sit` animation for 3-6 minutes. Afterwards it leaves 1-2 "Boba" or "Donut" spills on the table (via CleanlinessService) and is destroyed.
- **Patience.** There is no per-NPC patience bar. The only clock is `SegmentTimeout`, 5 minutes per segment. A 10 s audit despawns NPCs past that ("Looks like im past my welcome"). Orders also have a 3-minute unclaimed timeout and a 7-minute prepare limit in OrderService.
- **Pay and tips.**
  - On the cashier's correct submit: `CurrencyService:ModifyPoints(cashier, #items)`, times 2 during Rush Hour.
  - The barista gets `#items` points on deposit, doubled if the order is `_boosted`. `RewardService:OrderCompleted` runs once per item, which counts toward the Brew Bonus, with the "Apple Crazy" particle reward at 20 orders.
  - NPCs do not tip. `TipService` is for Robux tip-jar gamepasses between real players.
- **Rush Hour.** Every 35 minutes, and also via a dev product ("Spawn Rush Hour!", 3318558073). For 5 minutes each active register gets a queued NPC from `Customers.RushHourSpawn`, points are doubled, and a client camera effect runs (`RushCamera`, `RushHour` parts).
- **Look and animation.**
  - 5 stock `HumanoidDescription`s in `NPCStorage.Characters`: Big T, Rubert, Gilbert the Frog, JT, Grandpa. There is also `Special.Karen`, and loose `OldKaren` and `Karen` descriptions.
  - At KnitStart it also pulls `HumanoidDescription`s from about 28 real UserIds in `CustomerConfig.Appearances` (staff and partner-game owners) and files them into `Characters`.
  - An overhead `OverheadTemplate` BillboardGui says "NPC". There is a `Spawn` ParticleEmitter.
  - NPC animations in `NPCStorage.Animations`: Wave, Confused, BoothSit, ComfySit, CafeSit, CouchSit. `AnimationStorage.NPC` has Idle and Wave.
  - There are no happy, sad or impatient animations. The Karen "angry" cue is voice lines only.
  - Dialogue pools are in `ReplicatedStorage/Shared/Configuration/CustomerConfig`: Greeting, Followup, Leaving, Waiting, WrongOrder and WorkerAction, each with Default and Karen variants.
- **World nodes.** `Workspace.Assets.Customers`: `SpawnLocation` (-31,51,-128), `WaitingArea` (106,55,-170), `RushHourSpawn` (-26,54,-20), `RushHour`, `RushCamera`, the `Barriers` folder (12 invisible walls), `WorldStorage`. Also `Assets.Seating` (34 groups, each a Table model plus a Seating model of Seats) and the per-register `NpcZone`, which the OrderService script generates 5 studs in front of `Register.Frame`. There is no authored path or queue-node system. Movement is free pathfinding.

### OrderService (+ OrderStore, Queue, OrderScreen, QueueScreen) [src]
- Roles are Cashier (takes the order at a register, POS UI, `SendWalkIn` / `SendNonPlayer`) and Barista (makes it). Customers can also order from a Kiosk (`SendKioskOrder`).
- Baristas `JoinQueue` (or auto-queue with the "Star Employee" pass). When an order is created the longest-waiting order goes to the next barista in the queue. Player orders take priority over NPC orders. Assignment is by queue order, not tied to a particular NPC.
- The barista makes the item, then presses the prompt on a **Pick Up Area** node (`Workspace.Assets.OrderingSystem.PickUpStation`, 16 Parts, about x 71..89, z -159..-191) and chooses the item. For an NPC, the first chosen tool is reparented into the NPC's character. The NPC does not collect it. So **the serve happens at PickUpStation, not at the NPC.**
- Expiry: unclaimed orders after 3 minutes (the player customer gets a consolation item). A barista holding an order for more than 7 minutes loses it back to the queue.

### CleanlinessService (+ Spill) [src]
- Keeps 15 (`MaxSpawned`) Mopping spills alive at random `Workspace.Assets.Spills.Areas` parts (19 Floor parts), with `MaxTotal = 20` and the rest queued.
- Cleaning raises a replicated Cleanliness % (+1..2 per spill).
- The Boba spill has a TripRegion, with Trip sounds and a Trip signal. Tables get "Table" spills (Boba or Donut) from departing NPCs.
- Spill models: `ReplicatedStorage/SharedStorage/CleanlinessStorage/Spills/{Boba, MeltedPopsicle, Donut}`. Tools: `.../Tools/{Broom, MopBucket, Mop, DishTowel, SprayBottle}`. Also `Sparkles` and `Animations/{MoppingAnimation, SweepingAnimation, FallingAnimation, TableAnimations/{Cafe, Booth, Couch, Comfy}}`.

### StockingService (+ StockingObject, StorageBox) [src]
- `ReplicatedStorage.SharedStorage.StockingStorage` boxes. A player grabs a box, which sets the player attribute `Restocking` ("Seeking", "Puzzle" or "Unloading"). Carrying uses a `Carrying` animation. They restock station locations (models with `CurrentStock`, `DefaultStock` and `Id` attributes). Stock drops on use.
- Stock only drops when 3 or more baristas are online (outside Studio). Owning the **Unlimited Stock** gamepass (43707849) skips depletion.
- This is the **Restocking** gate used by TrashCans, JoinQueue and others: "You cannot do this while carrying a box."

### VendorService (+ VendorSetup) [src]
- Walk-up vendor stands under `Workspace.Assets.Vendors/<Stand>/{Stand, Spawn, Items}`. At start it clones `NPCStorage.Rig` onto each, applies a random `Characters` description and plays `AnimationStorage.NPC.Idle`.
- "Lemonade Stand" gives 5 free lemonade Tools (one per player) from `KitchenStorage.Tools`. "Pool Noodle Stand" sells the Pool Noodle for 25 Boba Bucks.

### ProductPurchaseService [src]
- Receipt processing and `BindToProductPurchase` / `BindToGamepassPurchase`. `InitiateBobaBucksPurchase` takes a confirm prompt and deducts from `playerData["Boba Bucks"]`. It is also used by TipService for tip-jar gamepasses.

## Per-question table
Dev-place column: from the repo only, no Studio. **[repo]** cites `S1/evidence.md`, which shows the dev place has its own `SoundService.SFX.Kitchen`, `Workspace.OldScriptables` and so on.

| Q | What v4 has | Also in dev place (repo can tell) |
|---|---|---|
| Q1 who serves which NPC | [src] No per-NPC auto-assignment. A cashier requests the NPC at their register and takes the order. The order then goes into one shared queue, and the next-in-queue barista gets the oldest waiting order, player orders before NPC orders. There is no "Rescue". `OrderService._getNextWaitingOrderForBarista`, `_setBaristaForOrder`. | No. The repo has no cashier or register concept for NPCs. |
| Q2 where is an NPC served | [src] Barista deposits at **PickUpStation** (`Workspace.Assets.OrderingSystem.PickUpStation`, 16 Parts, ProximityPrompt "Pick Up Area"). The tool is put straight into the NPC's character wherever it stands. The NPC (at `NpcZone`, 5 studs in front of its register) then goes to sit. | Unknown. S1 lists `Workspace.OldScriptables.NPCFolder.OrderPickup`, probably the same idea. |
| Q7 spawn | [src] 4 `SpawnLocation`s at `Workspace.Map.SpawnLocations`, about (-41..-11, 43, 157..186). That is outside and about 400 studs north of the kitchen (z about -200..-240). Front doors: `Workspace.Assets.FrontDoors` (LeftDoor, RightDoor, Zone) at about (-26,59,-1). There is no inside spawn. | [inf] Same shape (4 outside spawns), maybe the same objects. Can't confirm. |
| Q8 NPC route and counter | [src] No authored lane. NPCs path freely from `Assets.Customers.SpawnLocation` to a per-register `NpcZone`, then to `Customers.WaitingArea`, then to a seat in `Assets.Seating`. Counter spots are the 19 `Registers` (the Frame part, 5 studs back). No door node: the NPC spawns inside the café. The `Traversable`, `WanderPlanes` and `OldScriptables.NPCFolder` names do not exist in v4. Searched `traversable`, `wander`, `orderpickup`, `oldscript`, `npcfolder`, with 0 hits. | The new `Assets.NPC.{Entry, Exit, Path, Queue, Counter}` contract has no v4 equivalent. |
| Q9 trash cans | [src] `Workspace.Assets.TrashCans` has **14** can Models (positions in the Appendix). Handler: `ServerScriptService/Server/Services/Game Elements/TrashCans` (ModuleScript). Prompt "Use". Held Tool + confirm "Throw Away?" Yes/No. Blocked while `Restocking`, or when the Tool has `NotDisposable`. The model has a mesh `binmode_Cube.036` as primary part. | [repo] Jack's note: 6 cans with no handler in dev. v4 has 14, so the extra ones are not the same set. Compare positions. |
| Q19 content gaps | [src] None of Banana, Avocado, Honeycomb, Almond, Mint, Orange, Blueberry or Peach exist as syrups or tools. v4's `ItemData` has no syrup picker at all: Milk Teas with Jelly/Tapioca; Teas (Oolong, Green, Black, Jasmine, Ginger); Coffee (Regular, Americano, Espresso, Mocha, Vietnamese); Bakery (6 mochi donuts); Ice Cream (4 mochi + Boba Popsicle). `Workspace` has loose Parts named `avocado`, `peach`, `dragon fruit` near (-460, -1104, 1350) in a TestRigs animation area, and `ReplicatedStorage...Assets.AlmondMilkCarton`. Lemonade tools exist (Electric Berry, Green Apple, Lemon Sundrop, Strawberry Peach, Blood Orange). **No smoothie, fruit or pastry tools.** The only Tools in `KitchenStorage.Tools` are cups, Shaker, Dessert Wrapper, Boba Popsicle, 5 lemonades, Pool Noodle, TestBobaTool. | S1 lists Mochi/Macaron/IceCream/Cups/Smoothie tools in the dev place, a larger set than v4. |
| Q21 Unlimited Stock / Restocking givers | [src] `Restocking` is a **player attribute** set while carrying a stock box, not a giver. StockingService boxes refill station locations. The gamepass 43707849 skips stock depletion (`StockingObject:Use`) and also shows in `KitchenService` and `ProximityPromptScript.client`. There is also a "Restock Everything" dev product (3300910561). | [repo] Check dev for the attribute name. |
| Q22 sink / water | [src] No sink: searched `sink`, `faucet` with 0 hits. Water sources: `Workspace.Assets.Kitchen.HotWater/Hot Water` (4 models, near (+/-27..52, 52, -236)), `Coffee Stirrer/Water` MeshParts, and the IceMachines. A `Water` ItemData entry exists only in a commented block. | S1: dev has `Workspace.Assets.Kitchen.Givers.Coffee Machine.Water` and `Workspace.Map.WaterTouchPart`. |
| Q23 kitchen sounds | [src] `SoundService/SFX` has only Bell_01, Welcome_01, Error_01, Sound, Success_01..03, Trip_01/02, **Pour**, Pop_01/02, Hover_01. No `Kitchen` subfolder, no Sink, Machine or IceCubes sound. Blender has 4 `Blend` Sounds (`Workspace.Assets.Kitchen.Finalizers.Blender.Particles.Blend`). Mop and sweep Sounds under `MoppingAnimation/SoundProfile/{Splash, Sweeping}`. Also `Music/Summer Anthem`, `Ambiance/{MourningDove, Ambiance_Inside, Ambiance_Outside}`. Sound IDs UNVERIFIED. | S1 says the dev place has `SoundService.SFX.Kitchen.{SyrupPour, Pop, Blender}`, which v4 lacks. |
| Q24 spills | [src] Complete: `Workspace.Assets.Spills.{Areas (19 Floor Parts), Boards (3), Active}`. Storage is under `ReplicatedStorage.SharedStorage.CleanlinessStorage` with `Spills/{Boba, MeltedPopsicle, Donut}`, `Tools/{Mop, MopBucket, Broom, DishTowel, SprayBottle}`, `Sparkles` and `Animations`. The new SpillService expects `SharedStorage.Spills.{Spills.Boba, Tools.Mop, Tools.MopBucket, Sparkles}` [repo, init.luau lines 66-77]. v4 has all four, under the parent name **`CleanlinessStorage`** instead of `Spills`. | S1: dev has `Workspace.Assets.Spills`, `SharedStorage.Spills.Mop` (Accessory) and legacy `OldScriptables._Assets.Spills`. |
| Q25 NPC / barista look | [src] Animations for NPCs: Wave, Confused, 4 sits, Idle. Emotes for players include `Happy`, `Cheer`, `Celebrate`, `Shrug`, which exist but are not wired to NPCs. No sad or impatient. Uniform: yes. `KitchenStorage.Assets.{S,P}_DefaultUniform` and `{S,P}_SEUniform` (Shirt and Pants), plus `ReplicatedStorage/Shared/Cosmetics/Uniforms` (Default 15442083820/15442087539, Special, "Summer Brew Bonus", "A+ Brew Bonus"). The uniform is unlocked through the Brew Bonus UI (`BrewBonus/Uniforms`). No apron. | Not checked; dev has a "Uniform Remover" pass per Jack. |
| Q26 Celebrity | [src] No Celebrity NPC or folder in v4. `Celebrity` appears only as a **Shop tab** (`StarterGui/BobaUI/UI/Pages/Shop/Main/{List,Box}/Celebrity`) with a PurchaseModal of 3+ dev product IDs (1128806440, 1143304035, 1143304104). It is a Robux shop page, not a visit system. Searched `celebrit`. | `CelebrityFolder` is a dev-place thing; v4 does not help. |

## CustomerService: v4 vs `src/server/Modules/CustomerService/` (facts only)

| Topic | v4 [src] | New (init, Npc, Rules) [repo] |
|---|---|---|
| Who owns an NPC | The cashier at a register, one per cashier | No owner or assignment yet (Q1 pending) |
| Spawn trigger | Cashier button press, plus Rush Hour every 35 min | Automatic pacing: `Rules.PacingTarget(clocked-in baristas)`, spawn gap, cap |
| Order content | 1-3 random `ItemData` items, with modifiers | One item from `ORDER_POOL`, weighted, sized, resolved through `OrderSpec` |
| Where it stands | Per-register `NpcZone`, `WaitingArea`, then a seat | Authored `Entry/Path/Queue/Counter/Exit` parts |
| Order display | Chat lines from the NPC, read by the cashier | Billboard bubble with an order description and a patience bar |
| Patience | None, apart from the 5-minute despawn and the 3-attempt limit | Real patience, scaled by item; Green/Yellow/Red; pauses when nobody is clocked in; leaves with no penalty |
| Wrong order | Up to 3 attempts, `Confused` animation | Not built |
| Serve and pay | Barista deposits at PickUpStation; points paid to cashier and barista | Not built (Q2/Q5/Q6 pending) |
| After serve | Waits, sits 3-6 minutes, leaves spills | Not built |
| Look | Real-player and stock `HumanoidDescription`s, Karen at 10%, nametag "NPC" | Default R15 rig (Q25 pending) |
| Animations | Wave, Confused, sit variants | None |
| Movement | SimplePath, free-form, `PivotTo` fallback on error | `MoveTo` along nodes, 6 s segment timeout, `PivotTo` fallback, despawn after 3 in a row |
| Collisions | `PLAYERS_COLLISION_GROUP` from GameIntegrityService | Own NPC group that ignores players and other NPCs |
| Tests | None seen | `Rules` is pure and has a spec (`src/server/Tests/CustomerService.spec.luau`) |
| Kinds | Normal, Karen (voice only) | One kind |
| Seating and spills | Yes | No |
| Dependencies | Knit 1.x (`Knit.Services`), `Janitor`, `SimplePath` | Knit + `GoodSignal`, `OrderSpec`, `WorldPath` |

## v4 scripts and assets worth Jack's attention
1. `ServerScriptService/Server/Services/CustomerService` and its child `Customer` (15 KB): the complete NPC lifecycle including seating.
2. `ReplicatedStorage/Shared/Configuration/CustomerConfig`: dialogue pools (Greeting, Followup, Leaving, Waiting, WrongOrder, WorkerAction; Default and Karen), `MaxCapacity`, `MaxAttempts`.
3. `ReplicatedStorage/SharedStorage/NPCStorage`: `Rig`, 5 `Characters` descriptions plus `Karen`, `Animations`, `OverheadTemplate`, `ReservedSign`, `Spawn` particle.
4. `Workspace/Assets/Seating` (34 groups) and `Workspace/Assets/Customers`.
5. `ReplicatedStorage/SharedStorage/CleanlinessStorage` as a source for the SpillService's four missing paths (Q24).
6. `Workspace/Assets/TrashCans` (14 cans) and `Game Elements/TrashCans` (the handler).
7. `ReplicatedStorage/SharedStorage/KitchenStorage/Assets/{S,P}_DefaultUniform` and `Shared/Cosmetics/Uniforms` (Q25).
8. `Workspace/Assets/Kitchen`: a full two-sided kitchen (Tapioca, Jellies, Blender x4, LidSealers, PastryDisplays, IceMachines, HotWater, CupSleeves).
9. `Workspace/Map/TestRigs`, `AnimTemp`, `Shakeanim` and `BAckanim` at y about -1100: staging area for animations.

## Appendix: v4 trash-can positions (rounded)
(64,50,-110), (-430,25,-128), (-47,52,-17), (-94,52,-51), (127,52,-76), (110,52,2), (70,52,-66), (-44,50,-108), (-365,25,-140), (-38,49,-179), (30,49,-180), (-83,49,-193), (-83,49,-229), (74,49,-229)

## UNVERIFIED
- All AnimationId, SoundId and Image IDs (lune could not read Content properties).
- Whether any v4 asset is byte-identical to the dev place.
- That v4 is exactly the production build: this is inferred from IDs and guards.
- `old-v3.rbxl` and `current-baseplate-build.rbxl` were not opened.
