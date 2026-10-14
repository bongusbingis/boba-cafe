# REVIVAL-001 — Revival plan v2 (Prime, 2026-10-13)

**Status:** PLAN ONLY. No product code or place content was changed while producing it.
**Base brief:** `context-and-goals.md` (Jack's goals and decisions D1–D5). This plan
supersedes the phase plan in `handoff.md` §4. `handoff.md` stays as history. §1 lists
where this plan disagrees with it.
**Source state:** branch `uhweifh` at `92f6144`, plus untracked docs and `.review/`.
Studio "jacks project" (placeId 89999123284040, studio id `0bec4a01-…`) was in Edit mode
with Rojo connected. Live data was fetched from public Roblox APIs on 2026-10-13.
**End goal:** the rebuilt game is ready for testing and then for release over the live
place 718328620. There is no fixed deadline.

---

## 0. Decisions this plan is built on

| # | Decision | Source |
|---|---|---|
| D1 | Hybrid loop: NPC customers are the always-on baseline. Real players order through a chat-free kiosk UI. | Jack, 2026-10-12 |
| D2 | No new map. Use the existing build. | Jack, 2026-10-12 |
| D6 | Ship over the **same place, 718328620**. This keeps 46.4M visits, 218.7k favorites and the ratings. Players start fresh: no legacy currency or items carry over, and only gamepasses are honored. | Jack, 2026-10-13 |
| D7 | **Every legacy gamepass is remapped to a perk.** The pass catalog must let Jack put any off-sale legacy pass (Headless, Korblox, …) back on sale without code changes. | Jack, 2026-10-13 |
| D8 | Group ranks become **titles, moderation, and event hosting**. They no longer gate gameplay. | Jack, 2026-10-13 |
| D9 | **Solo + AI agents only.** No commissioned art, no ad budget. All art reuses existing assets or in-engine captures. | Jack, 2026-10-13 |

---

## 1. Verified facts, and corrections to the previous agent

### Live game (public APIs, 2026-10-13)
- Universe 312310157 is still the **old chat-RP build**, last updated 2026-08-12.
  - 3 playing.
  - 46,447,769 visits and 218,723 favorites.
  - 79,682 up / 23,270 down (77% like).
  - Max 70 players per server.
- Group 3174578 has **2,193,331 members**. There is no current shout. The owner account is `Flez_ent`.
- The store description still sells homework: the cashier quiz, `!apply` trainings, and DevForum handbooks.
- Legacy gamepasses: **14 on sale and 34 off-sale** (full list in §6.3). `Gamepasses.luau` knows only 11 of them.

### Corrections to `handoff.md`
1. **"The join kick explains ~3 CCU" is wrong.** The live game runs the old build. The
   rank-<4 kick in `src/server/init.server.luau:40-47` is a staff-only lock for testing
   this rewrite. It still has to go before release (it needs Jack's approval, which D8
   implies), but it is not why the live game is dead.
2. **"Kitchen station geometry not found; build proxy models" is wrong.**
   - `workspace.OldScriptables.KitchenFolder.Givers` holds **65 named station Models** sitting
     in the new kitchen: Coffee Machine, Blender ×4, Milk ×6, Ice Machine, Cup, Clear Cup,
     Mug, Lid ×4, Sugar, the tea and hot-chocolate powders, the tapioca wells ×2 each, Food
     Display, Ice Cream Freezer, Fruits Freezer and Restocking.
   - `KitchenFolder.Syrups.SyrupsArea` (39×1.5×1) also exists.
   - The names match `Recipes.Items` keys, and capture `Prime2_kitchen_interior` shows them in place.
   - `OldScriptables._Assets.OrderingSystem` has exactly the `Status Screens / Staff Screens / Pick Up` structure that `OrderService` indexes, plus 13 `Computers` (registers) and `CustomerAreas`.
   - `NPCFolder` (Spawn, Traversable ×16, WanderPlanes, OrderPickup), `SpillsFolder.Planes`, `ChestNodesFolder` (15), `LeaderboardsFolder` and `ShopsFolder` (Karen, Lucy, Noodle Man, Bomberman, Mysterious Stranger) all line up with the new map.
   - **Wiring is mostly re-parenting and renaming, not building.**
3. **Rojo is now synced.**
   - The Studio tree matches the repo: 13 server Modules, 4 Scripts, Tests and Configuration; client Modules.
   - `ServerStorage.__Rojo_SessionLock` is present.
   - Board task P0.1 is closed.
4. **New defect, high severity:** `ProcessReceipt.server.luau:8` does `WaitForChild("GetPurchases")`
   *before* it assigns `MarketplaceService.ProcessReceipt`.
   - `Networking` contains only `InventoryEvent`, so the callback never registers and **no purchase can ever be granted** in this place.
   - `PromoCodes.server.luau:12` (`RedeemCode`) and `RankClaiming.server.luau:15` hang the same way.
5. **New defect, critical for boot:** `Hud/TopBar.luau:31` does `workspace:WaitForChild("Ordering System")`
   while the module loads. App → Hud → TopBar is required during `AddControllersDeep`, so
   **client Knit never starts** while that folder is missing.
   - `Recipes.luau` and `RecipeConstructors.luau` error at require time (`SharedStorage.Tools.Kitchen` and `Animations.Kitchen` are missing). Verified: `require(Recipes)` fails in Edit.
   - `OrderService`, `SpillService`, `OrderController` and `SpillController` index missing world folders at load.
6. **The menu, the recipes and the givers disagree.**
   - Menu lists syrups that Recipes comments out (Avocado, Honeycomb, Almond, Mint, Orange, Blueberry, Peach), plus Latte, Oolong, Salted and Peppermint cocoa, and 16 smoothies.
   - Givers include Oolong, Peppermint, Salted, Fruits Freezer and Restocking, none of which have recipes.
   - Recipes uses `Lids`; the givers are named `Lid`.
7. **No order validation exists.** Staff deposit any tools they pick from an ActionPrompt list
   (`OrderService:_promptToolSelection`). Nothing checks that the drink matches the order.
   NPC customers cannot work until this exists.
8. **There is no gameplay income.** BobaBucks come only from promo codes and selling items. Points come from spills and are spent on nothing.
   - Capsules have display-string prices (`" 150"`) but no purchase path.
   - No `AnalyticsService` usage exists anywhere.

---

## 2. Diagnosis: why the game is dead (Prime's view)

The chat change was the trigger, not the root cause. The old design sells **status earned
through gated social labor**: you train, get ranked, then work the kitchen in front of
others. That design has three fatal properties on today's Roblox:

1. **It needs a crowd to be fun.** One player in an empty server has nothing to do, so new
   traffic bounces. Low retention makes the discovery algorithm stop recommending the game,
   which means fewer players and an emptier server. It is a death spiral.
2. **Its onboarding is homework.** The quiz, trainings and handbooks filter out exactly the
   casual players that recommendation traffic brings.
3. **Its monetization sells shortcuts past the gate** (the Barista and Kitchen Leader passes). With the
   gate removed, there must be a real progression for purchases to accelerate or decorate.

The assets are better than the CCU suggests: a finished map, a deep recipe system, 23 pets,
a capsule and hatch system, nametags and particles, a React UI shell, an ordering system, NPC
avatars and a 2.19M-member group. **What's missing is a loop that is fun with one player and
better with forty.**

What carries the release is **retention, not launch reach.** A group shout to 2.19M members
plus a store rewrite will create one spike of players. Whether Roblox keeps sending players
depends on how many of that spike come back (D1/D7), how long they stay, and whether they spend. So
the plan gates release on a playtested first-session experience and working return hooks,
not on feature count.

---

## 3. Product vision: "Run the cafe"

**Pitch:** *Make boba, serve customers, level up your barista, and collect pets. Solo or
with the whole server.*

### Design rules (every task is judged against these)
1. **Minute one:** a player who never chats and is in no group is making a drink within 60 s
   and has been paid within 90 s.
2. **Fun at 1 player, better at 40.** NPCs fill the cafe at any server population. Other
   players add co-op bonuses, real orders, competition and spectacle, but are never required.
3. **No chat dependency.** Everything a player needs to know is shown by icons, bubbles,
   highlights and UI. Emotes and reactions provide social expression.
4. **Every session has a goal and a reward.** A shift ends with a payout screen. A day ends
   with quests and a streak.
5. **Spend accelerates or decorates; it never unlocks basic play.** This is what makes the
   monetization sustainable and keeps ratings healthy.
6. **Simple code** (CONVENTIONS §1). Reuse the existing systems and avoid new frameworks.

### Loops
| Loop | Length | Contents |
|---|---|---|
| **Core** | 20–45 s | An NPC or player order appears as a ticket with icons. Grab a cup, then work through milk, syrup, tapioca and lid at stations, with the next station highlighted. Serve, and get paid a base amount plus a speed and accuracy tip, with a combo for consecutive perfect serves. |
| **Session** | 8–15 min | **Shift:** clock in, serve until the shift timer ends, then see an end-of-shift screen with stars, total tips, XP and a level-up. The CTA is "Next shift" or "Open a capsule". |
| **Meta** | days–weeks | Barista Level 1–50 unlocks menu items and stations in tiers. Collect pets, nametags and particles from capsules bought with BobaBucks. Daily quests, a login streak, a weekly limited capsule, and leaderboards for monthly tips and orders served. |
| **Server** | ongoing | **Cafe Rating**, which reuses the cleanliness meter: cleaning spills, serving fast and avoiding failed orders raise it. At 100% the server gets a timed boost ("Rush Hour" with more NPCs and 2× tips). There are also scheduled events and paid server-wide boosts. |

### Roles (no gating; switch any time)
- **Barista** (default for new players): clock in at the kitchen door. You wear an apron, see
  order tickets and are paid per serve.
- **Customer**: walk up to a kiosk or register screen and order through the
  `MobileOrder` UI (chat-free). A real player's order goes into the same queue as NPC orders,
  marked with a player badge.
  - Whoever serves it gets a **real-player bonus**.
  - The customer earns small "Regular" rewards: a stat, a daily-quest step, and the drink as a tool they can hold, sit with and emote with.
  - This keeps the social RP fantasy without chat.
- **Cashier**: optional, add after the MVP. An NPC at a register waits for the order to be taken.
  - A player at the register taps through the NPC's order. That is faster, and both cashier and barista get a bonus.
  - If no cashier is present, the NPC self-serves at a kiosk after a short wait.
  - This keeps the three-person fantasy when people are around, at no cost when they aren't.
- **Ranked staff (D8):** group rank shows as an overhead title (existing `PlayerOverheads`).
  - MR+ get moderation commands through **Cmdr**, which is already a dependency.
  - HR+ can start events such as Rush Hour, 2× XP, or Karen Day.
  - Trainings are replaced by **hosted events at scheduled times**, which keeps the community's appointment habit as a CCU spike.

---

## 4. System designs (what changes, using existing code)

Each item names the code it reuses. Roles follow `AI_AGENT_WORKFLOW.md`.

### 4.1 Open access (replaces the rank gates)
- Remove the join kick (`init.server.luau:40-47`). D6 and D8 imply this, but **Jack must
  confirm at the M0 review.**
- Replace `CanUseOrderingSystem` / `CanEnterKitchen` checks in OrderService, KitchenService and
  TopBar with a server-side **clocked-in state**:
  - It is a player attribute plus `Teams` (Customers and Baristas).
  - It is toggled by a clock-in prompt at the kitchen door or by a HUD button.
  - `RankUtil` stays for titles and moderation only.
- `RestrictedAreasFolder` (KitchenInner, OrderingInner, Office): keep the Office for ranked
  staff only, as prestige space (an approval-free cosmetic gate, not a play block). Open the rest.
- Spawn: the 4 spawns are in the exterior (≈(-238..-186, -4, 434..519)), about 300 studs
  from the kitchen. Move or add spawns inside the cafe near the clock-in point, or add an arrow trail.
  This needs a Rigger task.
- The first-join nickname modal (`PlayerSetup`, 3 s after join) blocks the first minute. Defer it
  until after the first shift ends, and make it skippable.

### 4.2 Order model and validation (the keystone; Architect, then Mason)
- **One canonical spec per orderable item.** Build a `DrinkSpec` / `OrderSpec` in shared,
  derived from `Menu.luau`, with fields `{ Base, Size, Syrup?, Tapioca?, Iced?, Lid? }` or `{ Grab = toolName }`
  for pastries and ice cream.
- Kitchen actions write **attributes** on the held tool as they run, using the same calls
  that already set colors and rename the tool (`SetToolHoldingProperty`, `RenameToolHolding`).
  Matching compares attributes, never display names.
- The server validates a serve by comparing the tool's attributes with the order spec. The result is perfect,
  close (wrong size or minor mistake: reduced tip) or wrong (rejected, with a clear UI reason).
  This is pure logic, so it gets **TestEZ** coverage.
- **Reconcile the content.** The launch menu contains only items whose full recipe works end to end with
  the givers that exist. Proposed launch set:
  - Boba teas: syrups present in both Recipes and Menu, × 10 tapioca, × 3 sizes.
  - Teas: 6, plus Oolong if a giver recipe is added.
  - Coffees: 7.
  - Hot cocoa: Classic, Caramel and Vanilla, plus Salted and Peppermint once their recipes exist.
  - Pastries and ice cream as grab items.
  - Smoothies stay off the menu until the Fruits Freezer and Blender recipe is designed.
  - Fix `Lids` vs `Lid`.
- Replace the deposit ActionPrompt flow with **auto-match**. Serving an NPC takes the
  held or backpack tool that matches its ticket. Depositing a player order at a pickup node
  auto-selects the matching tools.

### 4.3 NPC customers (new `CustomerService`; Forge, Architect, Mason, Rigger)
- **Bodies:** `SharedStorage.NPCs.Dummy` + `Characters` (112 HumanoidDescriptions) + `Overhead`.
- **Movement: fixed waypoint lanes, not pathfinding.**
  - The route is spawn door → queue spots → counter or pickup spot → seat (243 seats exist) or exit.
  - It is built from `NPCFolder.Spawn`, `Traversable`, `OrderPickup` and `WanderPlanes`.
  - Use Humanoid `MoveTo` between nodes. This is simpler and sturdier than SimplePath.
  - SimplePath stays available if it's needed later.
- **State:** server-owned. Each NPC has an order spec, a patience timer and a tip multiplier.
  The client renders the order bubble (item icons from SelectorModels viewports and
  ItemCard) and a patience ring.
- **Spawn rate scales with clocked-in baristas.** Starting point: one active NPC order per
  clocked-in barista plus one, with a server cap that is tuned in playtest.
  - This keeps the solo player busy without swamping them, and keeps the server load bounded.
  - Rush Hour raises the rate.
- **Variants, in phases:**
  - Regular.
  - VIP (gold overhead, big tip, impatient).
  - Karen: rude emote animation and very impatient, but a big reward. The Karen shop model exists.
  - Celebrity: rare. The `CelebrityFolder` and `CelebritiesMet` stat exist.
- **Failure:** when patience runs out, the NPC leaves with a sad emote. There is no penalty
  beyond a lost tip and a small Cafe Rating drop. Never punish new players hard.

### 4.4 Kitchen UX (Forge, Mason, Lens)
- **Recipe card on the HUD** while carrying an order: a checklist of steps for the active
  ticket, with the current step highlighted.
  - The next station gets a client-side `Highlight`. The existing `SyrupHighlighting` setting becomes "Station hints".
  - It reuses the `OrderTicket` component.
- Hold durations: keep the feel, but tune them so a basic boba takes about 20–30 s, including walking.
  Instant Brewing halves holds (KitchenController already reads this pass).
- Mobile first: most Roblox players are on mobile. Prompts must be tappable, and the SelectFrom dialogs
  (size and temperature) must be one tap each. Lens verifies on a phone aspect ratio.
- Drop the "Staff Guide" (`Pages/Recipes`) rank gate and turn it into an in-game recipe book
  that unlocks by level.

### 4.5 Progression and economy (Keeper owns; **all numbers are PROPOSED, for Jack's approval**)
- **Currencies:** keep **BobaBucks** as the single soft currency. Retire **Points** as a currency.
  Spills award XP and Cafe Rating instead. Keep `Points` in the profile template to avoid a migration, but stop showing it.
- **XP and Barista Level** (new profile fields `Level` and `XP`, reconciled into the new store).
  - Unlock tiers: L1 cups, milk, classic syrups, normal tapioca. L3 coffee. L5 teas. L8 hot cocoa. L10 more syrups. L12 flavored tapioca, and so on up to L50.
  - Every 5 levels gives a cosmetic: apron color, title, nametag.
- **Shift payout:** the sum of per-serve pay and tips, plus a star bonus.
- **Sinks:** capsules (the 4 existing ones), direct cosmetics, an optional "Cafe upgrades"
  sink later (server-wide decorations), and capsule skip with BobaBucks (in addition to Robux).
- Proposed starting numbers for Keeper to model before Jack decides. Do not implement until approved.

  | Item | Proposal |
  |---|---|
  | Basic order pay | 5–8 BB |
  | Perfect tip | +50% |
  | Combo | +5% per streak, capped at +50% |
  | Real-player order bonus | +100% |
  | Regular Pet Capsule | ≈ 10–15 min of play (existing price string " 75") |
  | Epic Pet Capsule | ≈ 2–3 h |
  | XP curve | L2 in the first shift, L10 by about the end of day 1, L50 in roughly a month of regular play |

- New profile store name (fresh start, D6). This is not destructive because the old live
  game's stores are never touched. Version the store with an environment suffix (§7.2).

### 4.6 Monetization (Keeper and Mason; **prices, perks and odds are Jack-approved**)
- **Fix the plumbing first (M0):**
  - ProcessReceipt registers its callback before anything that can yield.
  - An unmapped product returns `NotProcessedYet` instead of granting, and warns loudly.
  - Grants are idempotent on `PurchaseId`, recorded in the profile before returning `PurchaseGranted`.
  - Add `CurrencyService:TrySpend` (check and deduct atomically, refuse a negative balance).
- **Pass catalog (D7)** is in §6.3.
- **Developer products (proposed set):**
  - BobaBucks packs (the currency tab exists as mock data).
  - Skip hatch (exists).
  - Direct capsule purchase.
  - **30-minute personal 2× tips.**
  - **Server-wide "Boba Party"**: everyone in the server gets 2× tips or a Rush Hour for 10 min, and the buyer is announced on screen. This is a social spend that benefits everyone, and it is chat-free.
  - Tip-jar donation (legacy `Donate!` product IDs exist; reuse them if they are still on sale).
- **Shop:** wire every tab to real data and real prompts. Zero dead buttons is a release gate.
  - Prices are read from `MarketplaceService:GetProductInfo`, never hard-coded.
  - Retire the Celebrity tab, or re-theme it as a "VIP/Celebrity" pass.
- **Free income:** Premium Payouts come from Premium players' playtime, so retention also pays.
  Experience subscriptions and rewarded video ads are possible later additions; check eligibility and rules first. Both need Jack's approval.
- **In-world ad boards:** reuse `AdvertisementsFolder` SurfaceGuis to show live shop offers.
  The 13 legacy ad scripts must be audited before release, because they may prompt old passes.

### 4.7 Retention and social without chat (Forge, Mason)
- **Daily:**
  - Login streak on a 7-day calendar (reuse the archived `MainUI.Rewards` layout ideas).
  - 3 daily quests built on the stats that already exist: serve N, make N boba, clean N spills, serve N real players. This is the `QuestService` that `OrderService` already looks for.
  - The legacy **More Quests** pass maps to +1 quest slot.
- **Weekly:** limited capsule rotation, and leaderboard resets for the existing `LeaderboardsFolder` boards (Monthly tips, Most active, Top donators).
- **Collection:** pets follow the player (the system exists). The Collection page exists.
- **Social hooks:**
  - Emotes and reaction wheel.
  - "Made by \<name\>" on served drinks.
  - Co-op serves, where two baristas split one big order.
  - Real-player orders.
  - Friend invites (`SocialService:PromptGameInvite`) with an invite reward.
  - Experience notification opt-in (`ExperienceNotificationService`) for event start times.
  - Group join bonus (+10% tips; the free Ant Pet already exists).
- **Events (rank-hosted, D8, and on a schedule):** Rush Hour, Karen Day, Celebrity Visit,
  Treasure Hunt (reuse `ChestNodesFolder`, 15 nodes, and the `TreasureChestsFound` stat).
- **Badges:** the met-the-owner badges exist. Add milestone badges such as first serve, L10, 100 orders and first legendary pet.
  Optional, needs Jack's approval: a "Veteran" title for anyone who owns a legacy badge.
  Badges are universe-wide, so this is cheap and consistent with the fresh start.

### 4.8 Measurement (Mason; required before release)
Without numbers we can't tell what's working. Use `AnalyticsService` (Creator Dashboard):
- **First-session funnel:** joined → clocked in → first item picked up → first serve → first payout → shift complete → level 2 → first capsule opened → returned on D1.
- **Economy events:** every BobaBucks source and sink.
- **Custom events:** NPC timeouts, wrong-order rejects, average serve time, shop opened → prompt → purchase.

---

## 5. Technical foundation work (M0, mostly repo-only)

| # | Defect | File | Fix |
|---|---|---|---|
| F1 | Client Knit blocked by `WaitForChild("Ordering System")` while TopBar loads | `shared/UI/Components/Core/Hud/TopBar.luau:31` | Look the folder up lazily; the HUD must render without it |
| F2 | Errors at require time from missing Tools and Animations | `shared/Kitchen/Recipes.luau`, `RecipeConstructors.luau` | Paths come from the M0 world contract (§7.1). Missing tools or animations warn and skip that recipe |
| F3 | World indexed at load | `OrderService` (`workspace["Ordering System"]`), `SpillService` (`workspace.Assets.Spills`), `OrderController` (`Effects.PickupBeam`), `SpillController` | Resolve in KnitStart with a bounded wait; a missing folder disables that feature only |
| F4 | ProcessReceipt never registers | `server/Scripts/ProcessReceipt.server.luau:8` | Assign the callback first. **Create the remotes in code** (Networking folder and RemoteFunctions) instead of relying on authored instances. Same for `PromoCodes` and `RankClaiming` |
| F5 | Unmapped product consumes payment | same file | Return `NotProcessedYet`; add idempotency on `PurchaseId` |
| F6 | Currency can go negative; `Modify` gives no result | `CurrencyService.luau` | Add `TrySpend(player, type, amount) -> boolean` |
| F7 | Spill crash at 100% and busy loop | `SpillService/init.luau:62-71,116` | Add `SpawnInterval`; replace GlobalMulti with the Cafe Rating boost from §3 (design value, Jack approval) or remove it |
| F8 | `Spill.luau` expects a template and tools that don't exist (`Spills.Boba`, `Storage.Tools.Mop…`, `PromptService`, `ItemFader`) | `SpillService/Spill.luau` | Rigger checks `SharedStorage.Spills.Template`; Mason adapts the code to what exists |
| F9 | Duplicate `TableUtil` key | `wally.toml` | Pick one; check that `TableUtil.Random/Shuffle` callers still resolve |
| F10 | Join kick and rank gates | `init.server.luau:40-47`, OrderService, KitchenService, TopBar, BottomLeft | Replace with clock-in (§4.1). **Removing the kick needs Jack's confirmation** |
| F11 | `RankClaiming` and `RankingService` stubs | `server/Scripts/RankClaiming.server.luau`, `RankingService.luau` | Delete them; pass perks replace "claim rank" (§6.3) |
| F12 | `STUDIO_GRANT_ALL_ITEMS = true` | `init.server.luau:8` | Leave it Studio-only (it already has no effect live), but default it to false before release |

Gates for M0 (per AGENTS.md):
- No new Selene or StyLua findings in touched files.
- `rojo build` succeeds to a path outside the repo.
- TestEZ passes in Studio.
- **A 2-player Studio Play session has zero errors in Output** and both clients' HUDs render.

---

## 6. Content and catalog details

### 6.1 Launch menu
Built from the givers and recipes that exist; see §4.2. Forge makes the final list and Keeper sets the prices.

### 6.2 Assets we reuse (D9)
| Purpose | Asset |
|---|---|
| Map, kitchen, registers, pickup | `Map`, `OldScriptables.*` |
| Tools | `ToolsStorage`, 67 Tools: cups, pastries, ice cream, macarons, mochi, Golden Boba, balloons, floaties, Mop Whack, fireworks |
| Pets | `SharedStorage.Pets`, 27 |
| NPCs | `NPCs` (112 HumanoidDescriptions + Dummy) |
| Animations | 12 animations |
| Sounds | `SFX.Kitchen`, Music, UISounds |
| Old UI, as art reference and icons | `StarterGui.UIArchive`: old MainUI with Quests, Rewards, Tipping, Promotions, PetCapsule, Island |
| Thumbnails and icon | In-engine captures |

### 6.3 Pass catalog (D7): one config file plus one perk resolver
**Shape (Architect):**
- `shared/Configuration/PassCatalog.luau`:
  `[passId] = { Name, Perks = { "TipBoost25", … }, Listed = true|false, Legacy = bool }`
- `Listed` controls whether the shop shows the pass. Real for-sale state is set on the Roblox dashboard.
- Perk effects are defined once in `Perks.luau`.
- `PerkService:HasPerk(player, perk)` resolves ownership through `GamepassUtil`, which already caches it.
- **Owners always get the perks, whether the pass is listed or not.** Putting Headless or Korblox back on sale
  means: Jack turns the sale on in the dashboard, then sets `Listed = true`. Prices come from `GetProductInfo`.
- Stacking rule: multipliers in the same family take the highest value and do not add up. This keeps the economy sane.
- A legacy pass with no mapped perk falls back to a **"Legacy Supporter"** title, so no owner gets nothing.

**Proposed remap (perk values PROPOSED, Jack approval):**

| Pass (id) | Status | Proposed perk |
|---|---|---|
| Barista (6202153) | on sale, 499 | Permanent +25% tips & XP · "Barista" title · exclusive apron |
| Kitchen Leader (15243046) | on sale, 999 | +50% tips & XP (replaces Barista's) · title · exclusive nametag |
| Senior Barista (6202144), Staff Assistant (6202139) | off-sale | Same as Barista / Kitchen Leader tier respectively |
| VIP (12385781) | on sale, 399 | VIP lounge (patio / Premium Lounge area) · VIP nametag + chat tag · 2× daily reward |
| Premium Lounge (2126368) | off-sale | VIP lounge access |
| Star Employee (219650999) | on sale, 300 | +1 quest slot, 1 free daily quest reroll, auto-lid |
| More Quests (12385834) | off-sale | +1 quest slot |
| Instant Brewing (12385760) | on sale, 99 | Station holds ×0.5 |
| Faster Walk Speed (12385742) | on sale, 89 | Walk speed boost (existing setting) |
| Unlimited Stock (43707849) | on sale, 149 | Skips restocking (a light restock mechanic using the existing `Restocking` givers, to be designed) |
| x2 / x4 Multiplier (7564248 / 7564221) | off-sale | Tip multiplier family (values for Jack) |
| Double Storage (14067346) | off-sale | Inventory limit ×2 (`InventoryLimits.luau`) |
| Unlock All Pets (8022138) | off-sale | Exclusive legacy pet + a one-time pet capsule bundle (Jack to decide) |
| Nametag Customizer (29083693), Name Color Changer (7692868) | on sale / off-sale | Nametag color picker (`NametagColors`, 28) |
| Rainbow Pack (12385796), Rainbow Trail/Name/Overhead Tag (7105859/7105851/4185499), GOLD Overhead Tag (4185488), Heart NameTag (8168950) | mixed | Matching nametag or trail cosmetics |
| Headless Head (14067340), Korblox (12385818), Uniform Remover (219651224) | on sale / off-sale | Avatar options (the HeadlessHead setting exists; Uniform Remover hides the barista apron) |
| Emote Pack (219651061) | on sale, 85 | Emote wheel extras |
| Mop Whack (40973940), Flying Mop (219651106) | on sale | Fun tools (Mop Whack tool exists) |
| Golden Boba, Red Balloon, Balloon ×3, Heart Tool, Selfie Stick, Hoverboard | off-sale | Tool given on spawn, where the asset exists (Golden Boba and Red Balloon do); otherwise the Legacy Supporter title |
| Water Pack, Jet Ski ×2, Party Boat, Waterslide, Drop Tower, Beach Pass, Unlimited Fun Pass | off-sale | Outdoor water-area perks (JetSki model in `FunPassStorage`; pool, slide and canoes in the map) |
| Unlimited Song Requests ×2, Donation, UNUSED | off-sale | Legacy Supporter title (song requests only if a jukebox is built) |

Developer products in universe 312310157 can't be listed without authentication. Jack
needs to export or confirm that list before M3.

---

## 7. World contract and environments

### 7.1 World contract (Rigger; documented in `docs/SYSTEMS.md`)
Code reads **one** contract, and every path is resolved at KnitStart with a bounded wait:
- `workspace.Assets.Kitchen` ← re-parent `OldScriptables.KitchenFolder`: Givers (renaming `Lid`→`Lids` or the recipe key) and `Syrups.SyrupsArea`.
  - ~~`SelectorModels.Kitchen.SyrupDispenser` must be built~~ **WRONG (corrected 2026-10-14, M0.11):** Jack's dispenser exists in ServerScriptService's Archive/Services/KitchenService/SyrupDispenser. Use it. Never build replacements for assets that may already exist.
- `workspace["Ordering System"]` ← `OldScriptables._Assets.OrderingSystem`.
- `workspace.Assets.Spills` ← `OldScriptables.SpillsFolder` and `_Assets.Spills`.
- `workspace.Assets.NPC` ← `OldScriptables.NPCFolder`, extended with lanes and seat nodes.
- `ReplicatedStorage.SharedStorage.Tools.Kitchen.{Cups, IceCream, Pastries, …}` ← cloned and organized from `ToolsStorage`.
  - `Animations.Kitchen` ← clone the flat animations.
  - `Effects.PickupBeam` ← build it.
- Things code should **create itself** instead of depending on the place: Networking remotes, `ModelStorage`, `ServerStorage.OrderPickUp` (which already happens).
- **Audit the 17 legacy scripts** in OldScriptables before release: the ad boards, Elevator, Zipline, Fruits Freezer `StockRandom`, and IslandTeleporter. Keep, rewrite or delete each one.
- Delete what's dead after the move: old `OldScriptables` leftovers and `UIArchive`. **Wait until M6**, and keep a copy of the place file first.

### 7.2 Environments
- **Dev:** "jacks project" (89999123284040, a separate universe). All feature work and MCP playtests happen here.
  - Gamepass *ownership* checks work there by pass ID.
  - **Developer product purchases do not.** Products belong to the live universe.
- **Staging:** a new place inside universe 312310157, created by Jack. This is a publishing action, so it is Jack-gated.
  - Needed from M3 for real purchase and receipt tests and for staff playtests.
  - It shares DataStores with live, so profile and receipt store names get an environment suffix keyed off `game.PlaceId`.
- **Live:** 718328620. Publishing is Jack-only.
  - The rollback path is Roblox place version history: revert to the last old-build version.
  - The old game's DataStores are never written, so a rollback keeps old players' data intact.

---

## 8. Milestones and task graph

Each milestone ends with a **Jack review** (a short evidence packet: captures, test output,
funnel numbers where available). IDs go on `board.json`.

### M0 — Foundation: the game boots clean (repo + Studio)
| ID | Role | Work |
|---|---|---|
| M0.1 | Rigger | World contract §7.1: re-parent and organize under a Studio lease, then capture evidence |
| M0.2 | Mason | F1–F9 and F11 (repo-only, can run in parallel with M0.1 except F2 and F3, which need the contract paths) |
| M0.3 | Mason | F10, clock-in state replacing rank gates (after Jack confirms removing the kick) |
| M0.4 | Gauge + Sentry | Gates from §5; 2-player Play test; receipt-path review |

**Exit:** 2-player Play has zero Output errors. Kitchen prompts appear on every station, and
one hand-made boba can be made and deposited with no rank. All repo gates pass.

### M1 — Vertical slice: "serve one NPC" (the riskiest bet, proved first)
| ID | Role | Work |
|---|---|---|
| M1.1 | Architect | OrderSpec, tool attributes and the matching contract (§4.2) |
| M1.2 | Forge | First-session spec: spawn → clock in → first order → payout. Launch-menu subset for the slice (3 items: Classic Milk Tea Boba, Regular Coffee, a pastry) |
| M1.3 | Mason | OrderSpec + attribute-writing actions + validation + TestEZ |
| M1.4 | Mason + Rigger | `CustomerService` MVP: one NPC kind, waypoint lane, bubble, patience, serve prompt, BobaBucks payout |
| M1.5 | Mason + Lens | Recipe card and station highlight; mobile check |
| M1.6 | Gauge | Solo playtest with timings: time to first serve, failure reasons |

**Exit:** a fresh Studio player with no group and no chat serves an NPC within 90 s, and is paid.
Jack plays it.

### M2 — Core game
- Full NPC system: rate scaling, variants (VIP, Karen), seating and exit.
- Full launch menu.
- XP, levels and unlocks; shifts and the end-of-shift screen.
- Kiosk ordering for real players (MobileOrder as a page, with CreateOrder returning a result).
- Auto-match pickup.
- Cafe Rating (repaired spill system).
- AnalyticsService funnel.
- Spawn and first-session polish. Nickname modal deferred.

**Exit:** a 15-minute solo session feels complete: goal, reward, level-up, a reason to come back.
A 3-client Studio test with a real-player order works.

### M3 — Economy and monetization (Keeper-led; Jack approves every number)
- Economy proposal doc with numbers and a sink/source model. **Jack approval gate.**
- PassCatalog + PerkService + legacy remap (§6.3). Product set (§4.6). Shop fully wired.
- Purchases history page. Capsule purchase with `TrySpend`.
- Staging place (Jack action) for real purchase tests: idempotency, an offline-buyer retry,
  and a refused unmapped product.

**Exit:** every shop button works. Each product and pass was bought in staging, and its
grant was verified and re-verified after a forced retry.

### M4 — Retention and community
- Daily streak and daily quests (QuestService).
- Leaderboards: reuse the boards with monthly reset.
- Events: Rush Hour, Karen Day, Treasure Hunt; Cmdr commands for rank-hosted events and moderation (D8).
- Rank titles; milestone badges; invites, notifications and the group bonus.

**Exit:** D8 is fully delivered. A returning player on day 2 has a streak reward, new quests and a
visible goal.

### M5 — Polish, performance and safety
- Mobile, console and PC UI pass (Lens).
- NPC and server performance at the target server size. Decide max players (currently 70; propose 30–40 so servers feel full; set by playtest).
- `StreamingEnabled` decision.
- Exploit review of every remote (Sentry).
- Audit or delete the legacy scripts. Clean up `OldScriptables` and `UIArchive`.
- Docs: `SYSTEMS.md` and `ARCHITECTURE.md` updated (Quill).

### M6 — Test (closed, then open)
- **Staff playtest in staging.** The existing ranked staff become the test team; this is a good
  early use of D8 and keeps the RP community invested. Use a feedback form and the analytics funnel.
- Fix pass. Release-candidate freeze. Full release gate: Gauge, Sentry, Lens, Keeper, Quill.

### M7 — Release (every step is Jack-gated)
- Store rewrite that sells the loop, with no homework. In-engine thumbnails and an optional
  trailer built from captures. Icon refresh using existing art.
- Launch plan:
  - A group announcement (needs whoever holds group admin; the owner is `Flez_ent`).
  - Comeback promo codes.
  - Launch-weekend 2× tips event, with events scheduled at fixed times for the first 2 weeks.
- Publish to 718328620. Monitor the funnel, errors and revenue daily for 2 weeks. Hotfix lane open.
  The rollback is the place version revert (§7.2).

### Dependency sketch
```
M0.1 ─┬─> M0.2(F2,F3) ─> M0.4 ─> M1.* ─> M2 ─┬─> M3 ─┐
M0.2 ─┘   M0.3 (after Jack OK)               └─> M4 ─┴─> M5 ─> M6 ─> M7
M1.1 (Architect) can start during M0.
M3 economy proposal (Keeper) can start during M2.
```

---

## 9. Success criteria

**Release gates (pass or fail):**
1. A new player with no group membership, no chat and a mobile layout serves the first order within 90 s.
2. Fun at 1 player (NPCs) and at 20+ (Studio multi-client and the staff playtest).
3. Zero dead shop buttons. Every pass and product was bought end to end in staging. Receipts are idempotent.
4. No join kick and no rank gate on play. A missing optional asset never blocks play.
5. Analytics funnel live. Release package (store copy, thumbnails, codes, group post, event schedule) ready.

**Post-launch targets** (rough Roblox benchmarks, to be revised with real data):
- D1 retention ≥ 15%.
- Average session ≥ 12 min.
- Payer conversion ≥ 1%.
- CCU stays well above the pre-launch baseline 2 weeks after the spike.

---

## 10. Risks
| Risk | Mitigation |
|---|---|
| Veteran RP community backlash over losing gated ranks and the fresh start | Ranks become titles, moderation and hosting (D8). Staff are the M6 playtest team. Legacy passes are honored (D7). Optional Veteran title |
| Too much scope for a solo dev | M1 slice first. The launch menu is a subset. Cashier role, Cafe upgrades and smoothies are post-launch |
| Order validation becomes fragile across 60+ items | Attribute-based spec with TestEZ tables. The menu only lists items with a verified recipe |
| NPC server load | Waypoint lanes and a server cap scaled by baristas; measured in M5 |
| Purchases can't be tested in dev (different universe) | Staging place in the live universe (M3) with suffixed stores |
| One spike that the algorithm doesn't sustain | Gate release on the first-session funnel and return hooks, not on feature count |
| Legacy place scripts (ad boards, zipline) misbehave | Audit in M5; delete or rewrite |

---

## 11. Open questions for Jack (none block M0 or M1)
1. **M0:** confirm removing the staff-only join kick. (It's a play block, so the docs require your explicit OK.)
2. **M3:** economy numbers (§4.5) and pass perk values (§6.3); the developer product list from the live universe dashboard.
3. **M7:** who can post group announcements and edit the store page? The group owner is `Flez_ent`.
4. **M4:** a Veteran title for legacy badge owners, yes or no?
5. **M5:** max server size (proposed 30–40).
