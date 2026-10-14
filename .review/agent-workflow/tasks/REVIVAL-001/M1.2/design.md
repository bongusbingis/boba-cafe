RESULT: PASS
Spec complete. M1.3 can start now (it depends on no open question). M1.4 and M1.5 wait on the "Blocking M1" questions in §10 (Q1–Q9).

# REVIVAL-001-M1.2: Gameplay redesign and first-session spec (Forge)

- Date: 2026-10-14. Role: Forge. Source state: branch `uhweifh` at `92f6144` plus the uncommitted tree (M0.x work). No Studio access; the facts below come from repo greps and existing evidence.
- Inputs: `context-and-goals.md`, `decisions.md` (DEC-002 to DEC-008), `revival-plan.md` §1–§4 and §6–§8, `M1.1/design.md`, `M0.4/runtime-2.md`, `M0.7/evidence.md`, the board, and targeted reads of `Recipes.luau`, `RecipeConstructors.luau`, `Menu.luau`, `KitchenService/init.luau`, `ShiftService.luau`, `OrderService.luau`, `KitchenController.luau`, `KitchenConfig.luau`, `SettingsConfig.luau`, `ProfileTemplate.luau`, `Capsules.luau` and `CapsuleConfig.luau`.
- Scope: design only. Nothing outside `M1.2/` was changed.

## 0. How to read this spec

Every design point carries one of these labels:

| Label | Meaning |
|---|---|
| **SETTLED** (source) | Already decided by Jack's goals, the decisions log, or the adopted plan (DEC-003). The source is cited. |
| **PENDING JACK: Q<n>** | A core choice that nothing settles yet (DEC-008). The spec describes the **recommended** answer so that implementers can see the whole shape, but no task may build it until Jack answers. §10 holds every question. |
| **PROPOSED** | An economy number: a price, reward, probability or multiplier. Keeper models it and Jack approves it. Never ship one unapproved. |
| **TUNING** | A feel number such as a hold time, a patience length or a spawn gap. Forge sets the default, playtests adjust it, and it is not an economy value. |

**Facts this spec depends on (verified by grep on 2026-10-14):**
- Stations bind **by Model name** under `workspace.Assets.Kitchen` (`KitchenService:_getMatchingModels`). Any Model whose name matches a `Recipes.Items` key gets that recipe's prompt.
- Current hold times in seconds: Clear Cup and Cup 0.5, Mug 0, Milk 2, each Syrup 2, each Tapioca 2, Blender 5, Coffee Machine 7, Ice Machine 5, Sugar 1, Lids 1, Food Display and Ice Cream Freezer 1, Sink 3, tea and cocoa powders 2. The Instant Brew pass sets every hold to 0.5 s on the client (`KitchenController`).
- Boba takes tapioca with or without the Blender (`Recipes.luau:331`, after M0.7). The Ice Machine gate accepts only exact coffee names, so ice has to go in before sugar (`Recipes.luau:241`).
- `PROMPT_DISTANCE = 6` and `MAX_INTERACTION_DISTANCE = 10` (`KitchenConfig`). M0.4 measured counter standing spots at 6.06–6.29 studs from the Cup prompt.
- `KitchenService.Client.InteractionFailed` has **no client listener**, so every failed station use is silent today.
- `ShiftService` owns the `ClockedIn` attribute, and **new players start clocked in** (`DEFAULT_CLOCKED_IN = true`). The Teams are Baristas and Customers.
- `OrderService` allows one `Being Prepared` order per barista and has a barista wait-queue (`_joinQueue` and `_tryDispatchFromQueue`). Real-player ordering works end to end (M0.4 §4).
- Capsules: Regular Pet 75, Rare Pet 250, Epic Pet 800 and Nametag 150. These are display strings with no purchase path yet. A hatch takes 15 min of **active play** (`CapsuleConfig`). There are 23 pet definitions, all cosmetic.
- `SettingsConfig` puts `MinRank = 7` on `SyrupHighlighting` and `ShiftTimerEnabled`. That is a rank gate on a setting.

**Claims I could not confirm.** Each one is an asset question in §10, and nothing here designs around its absence: a sink, the kitchen sounds, the spill assets, dispensers for 8 menu syrups, fruit and pastry tools, trash-can locations, whether the NPC nodes fit the new map, counter spots, an apron, NPC animations and spawn spots.

---

## 1. The game in one paragraph

**Boba Cafe is a chat-free barista job sim.** Customers walk up to the counter with their order floating above their heads. Most are NPCs; some are real players who ordered at a kiosk. You grab a cup and run the stations the HUD lights up for you: milk, syrup, tapioca. Then you hand the drink over for BobaBucks, with bigger pay for speed, accuracy and perfect-serve combos. Every few minutes a shift wraps up with stars, a bonus and a level-up. Levels widen what your customers order, let you juggle more tickets, and bring in harder customers who tip more. BobaBucks buy pet capsules that hatch while you work. Together the server fills a Cafe Rating meter, and when it is full Rush Hour hits everyone at once. Group staff host events instead of trainings. Anyone can clock out and be a customer at any time.

**Why this beats the old RP loop for a 3-CCU game with a 2.19M-member group:**
1. **It works at 1 CCU.** The old loop needed a trained cashier, a trained barista and a customer online together, all chatting across age groups. Here NPCs supply every missing role, so the first player in an empty server is earning in under a minute. That is what stops the empty-server death spiral (plan §2).
2. **It needs no chat at all.** Orders are icons and text bubbles, guidance is highlights, and feedback is numbers and emotes. The age-segmented chat change cannot touch it.
3. **It turns the homework into the game.** The quiz, `!apply` and the trainings become a 4-step recipe card that the HUD teaches in 30 seconds.
4. **It keeps what the community valued.** Real customers, the barista fantasy and staff ranks all survive, as an optional role, a default role and titles plus hosting (D8). The 2.19M group becomes the relaunch audience and event attendance, not a gatekeeper.
5. **It has something for money to accelerate or decorate** (plan rule 5): levels, capsules, server boosts and cosmetics. The old game had only shortcuts past a gate.

**Where I disagree with `revival-plan.md`** (each disagreement is a question for Jack, not a decision):

| Plan text | My position | Q |
|---|---|---|
| §3 Roles: "Barista: clock in at the kitchen door." | New players start clocked in, as the code already does. Clocking in and out is a HUD toggle with no trip to a door. | Q4 |
| §3 Loops, Session: "serve until the shift timer ends." | A shift is a **count of customers** (10, and 5 for the first shift). It always ends just after a serve and never in the middle of a drink. | Q11 |
| §3 Meta and §4.5: "Level 1–50 unlocks menu items and stations in tiers… L1 cups, milk, classic syrups. L3 coffee. L5 teas…" | **No locks.** Every station works from level 1, so any real player's order can be made. Levels widen what *NPCs order from you*, add ticket slots and customer types, and give cosmetics. Coffee is already in the L1 slice (plan §8, M1.2). | Q10 |
| §4.3: "The client renders the order bubble (item icons from SelectorModels viewports and ItemCard)." | Each NPC bubble is server-built text plus a colour chip. Viewports appear only on your own HUD ticket, because 16 ViewportFrames in BillboardGuis are too heavy on phones. This is a UX and performance detail, not a core choice. | — |
| §4.7: "Co-op serves, where two baristas split one big order." | Replace it with a **Rescue** (serve a teammate's customer who is about to leave) plus a server **Team Combo**. Neither needs order-splitting code. | Q18 |
| §4.2: "Fix `Lids` vs `Lid`" (an implied Lid step) | Lids are not required on any drink. | Q3 |
| §6.3: Unlimited Stock gets "a light restock mechanic to be designed" | Don't build restocking, which is a chore. Remap the pass to a different perk. | Q21 |
| Silent on pets having any function | Ask whether an equipped pet gives a small tip boost. | Q16 |

---

## 2. Minute-by-minute first session (spawn → second shift)

This section describes the target experience. The "Built in" column shows which milestone delivers each row. Timings run from the moment the character spawns, assuming spawns are inside the cafe (**PENDING JACK: Q7**).

**Rules for the first session** (**PENDING JACK: Q4**):
- No modal of any kind before the first serve.
- No unsolicited purchase prompts before shift 2 ends.
- No nickname prompt until after shift 2 (the plan's deferral, made concrete).
- The first 3 customers are scripted and their patience is paused.
- A guidance beam appears for the first 3 customers, and again the first time each new item shows up.

| t (target) | What the player sees | Input | System and feedback | Built in |
|---|---|---|---|---|
| 0:00 | Spawns inside the cafe, 30 studs or less from the Clear Cup station, already clocked in (team Baristas). HUD: BobaBucks, Clock Out button, an empty ticket area. | — | `ShiftService` default clocked-in (exists). `CustomerService` sees a fresh profile (`CustomersServed == 0`) and places scripted Customer #1 directly on a free counter spot (no walk-in). | M1.4 |
| 0:01 | Customer #1's bubble reads "Medium · Classic Milk Tea Boba", patience bar hidden. A toast at top centre says "A customer is here! Make their order." The ticket and recipe card slide in at top left. Step 1 is lit, the Clear Cup station has a Highlight, and a beam runs from the player to it. | — | `TicketChanged` reaches the client. KitchenController draws the Highlight and beam. | M1.4, M1.5 |
| 0:03–0:08 | Walks to Clear Cup. The prompt reads "Clear Cup · Hold E" (a press-and-hold on mobile). | Hold 0.5 s | The size dialog opens with Small, Medium and Large. **Medium pulses** because it matches the ticket. | M1.5 |
| 0:08 | Taps Medium. The cup appears in hand, step 1 ticks ✓, and the beam moves to Milk. | Tap | Attributes `Item=Clear Cup, Size=Medium` are written (M1.3). The card reads them. | M1.3, M1.5 |
| 0:10–0:14 | Milk station. | Hold 2 s | ✓2. Beam to the Classic Milk Tea syrup dispenser. | — |
| 0:16–0:20 | Syrup dispenser. Only the right dispenser is highlighted. | Hold 2 s | ✓3. Beam to the Normal Tapioca well. | — |
| 0:22–0:26 | Tapioca well. | Hold 2 s | ✓4. The tool sparkles. The card says "Serve your customer!", and the customer gets a Highlight and the beam. | — |
| 0:28–0:32 | Walks to the counter. The prompt reads "Serve · Hold E" with a 0 s hold. | Tap | The NPC cheers. "+5" floats up over the NPC, a coin sound plays (if the SFX exists, **Q23**), and a toast reads "Perfect! Fast!". BobaBucks count up. **Paid at about 0:32. Hard limit 0:90.** | M1.4 |
| 0:33 | Customer #2 is already standing at the next counter spot: "Fudge Brownie". | — | The beam goes to the Food Display. | M1.4 |
| 0:35–0:45 | Food Display. In the picker the Fudge Brownie card pulses. Serve. "+2". | Hold 1 s, tap, tap | This teaches that orders vary and some are quick. | M1.5 |
| 0:46–1:15 | Customer #3: "Small · Regular Coffee". Cup (Small) → Coffee Machine, with Regular pulsing in the picker → serve. The toast reads "Combo ×3!" | 3 stations | The first coffee is guided with the beam. | — |
| 1:15 | Customer #4 is random from the L1 pool (§4.4). **Patience is visible for the first time**: a bar under the bubble, green, then yellow at 50%, then red at 25%. No more beam; the Highlight stays (the "Station hints" setting defaults on). | — | | M1.4 |
| ~1:50 | Customer #5. The ticket header reads "Shift 1 · 4/5". | — | | M2 |
| ~2:30 | **Shift 1 ends** (first shift = 5 customers, **Q11**). The **only full-screen card of the session** appears: stars, customers served, BobaBucks (pay + tips + shift bonus), best combo, and an XP bar that fills to **LEVEL 2** with the unlock reveal "Customers now order Taro and Strawberry!" Then the starter reward "Free Pet Capsule: hatches after 15 min of play" (**Q15**). Buttons: **Next shift ▶** (auto-continues after an 8 s countdown) and "See my pet". | Tap or wait | The next customer is already in line, so there is no dead time. | M2 |
| 2:40 | Shift 2 begins (10 customers). New syrups get the beam the first time each is ordered. A small hatch timer appears on the HUD. | — | | M2 |
| ~4:00 | A likely first mistake, such as the wrong syrup. **The card marks step 3 ✗ the moment the syrup goes in**, not at the serve: "Wrong syrup: needs Taro. Trash it at a bin." A bin gets a Highlight if bins are wired (**Q9**). | — | Early detection comes from `OrderSpec.StepState` (§3.8). | M1.5 |
| ~5:00 | The first time the Cafe Rating meter moves, a tooltip says "Fast, perfect serves raise the Cafe Rating. At 100%: Rush Hour!" | — | | M2 |
| ~6:30 | A spill appears, if spills are restored (**Q24**). A toast says "Spill! Clean it for Cafe Rating." The task is optional. | — | | M2 |
| ~7:30 | **Shift 2 ends.** This time it is a compact, non-modal card at the bottom centre for 6 s: stars, earnings, and probably L3 ("Hot Cocoa unlocked"). Below it, two optional prompts: "Daily quests (3)" (M4) and "Set your barista name" (the deferred nickname, skippable). | — | | M2, M4 |
| ~17:30 | The pet hatches with a celebration and starts following the player. | — | The existing hatch system. | M3 |

**Failure budget.** If the player wanders off, nothing times out. The scripted customers wait forever, and after 20 s idle the beam pulses and the toast repeats once. If any authored path is missing, `CustomerService` warns and turns itself off, and the kitchen still works (CONVENTIONS §1).

---

## 3. Core loop redesign: the kitchen

### 3.1 Principles
1. **Every step is either a choice that the ticket tests (size, syrup, tapioca, coffee type, ice, sugar) or a beat under 2 s.** A step that is pure ritual has to justify itself or go.
2. **Four stations is the ceiling for a level-1 item.** Walking between stations is the job-sim feel, and also the main cost on mobile.
3. **Mistakes are caught early and are cheap.** Nobody ever loses BobaBucks.
4. **The HUD teaches. There is no tutorial text wall** (Roblox onboarding guidance: "get to the fun quickly", contextual and action-based teaching; see Sources).

### 3.2 Chains per item (**PENDING JACK: Q3** for boba, **Q14** for the hold changes)

| Item | Recommended chain (card order) | Choices tested | Holds today → recommended (TUNING) |
|---|---|---|---|
| Boba (all syrups) | Clear Cup (size) → Milk → `<Syrup>` Syrup → `<Tapioca>` Tapioca | Size, syrup, tapioca | 0.5 + 2 + 2 + 2, unchanged |
| Coffee | Cup (size) → Coffee Machine (type) → [Ice Machine] → [Sugar] | Size, type, ice, sugar | Coffee Machine 7 → **4**, Ice 5 → **3** (Q14) |
| Hot Cocoa | Mug → Milk (steamed) → `<Flavor>` Hot Chocolate Powder | Flavour | 0 + 2 + 2, unchanged |
| Grab (pastry, macaron, mochi, ice cream) | Food Display or Ice Cream Freezer (picker) | Item | 1, unchanged |
| Tea, Water | Cup (size) → **Sink** → [powder] → [Ice] | — | **PENDING JACK: Q22** (the sink asset) |

- **Blender:** the recommendation is to drop it from the boba chain (**PENDING JACK: Q3**). It adds 5 s and one station but tests no choice. Since M0.7 a blended drink is still valid, so leave the station working (harmless, and fine for role-play) but never show or highlight it. It stays reserved for smoothies, if those come back (Q19).
- **Lid:** the recommendation is to require it on nothing (**PENDING JACK: Q3**). It tests no choice. The prompts stay so players can still add lids for fun. The `Lids`/`Lid` name mismatch is an asset question (Q3 asks it together with the chain).
- **Sizes:** the recommendation is to keep Small, Medium and Large (**PENDING JACK: Q3**). Reading the size on the ticket is the cheapest accuracy test there is. A wrong size grades as Close (less pay), not Wrong.
- **Ice before sugar:** until Q14 is answered, the card always lists Ice before Sugar, which matches what the gate enforces today. If Q14 is approved, station gates switch from names to attributes, and ice and sugar then work in either order.

### 3.3 Naming vs attributes
**SETTLED (M1.1 §3–§4):** serves match on tool **attributes** (`Item`, `Size`, `Syrup`, `Tapioca`, `Iced`, `Sugar`), never on names. Names stay because the `ToolNameValidityCheck` gates and role-play display read them. Rewriting the station gates to read attributes is a later simplification (**PENDING JACK: Q14**). It is not part of M1.

### 3.4 Error forgiveness (**PENDING JACK: Q5**)

| Situation | Feedback | Recovery |
|---|---|---|
| Wrong station for the current tool (for example Tapioca on an empty cup) | Toast "Next: Milk", and the correct station pulses. Today this fails silently. | Use the right station. |
| Using a station while clocked out | Toast "Clock in to use the kitchen" with a Clock In button. This is on the M1.0 list; M1.5d covers it if M1.0 has not. | Tap Clock In. |
| Wrong choice mid-chain (syrup, tapioca, coffee type) | The card marks that step ✗ at once with the reason. | Trash at a bin (Q9), or serve it to another customer whose order it matches. |
| Wrong size, or a missing or extra ice or sugar (one minor mistake) | The card shows a yellow "Wrong size: smaller tip" while you make the drink. | Serve anyway: graded **Close**. |
| Serving a drink graded Wrong | Toast with the reason, the NPC shakes its head, and the **tool is kept**. Nothing else happens; the combo is not broken. | Fix it or trash it. |
| Customer walks out | Toast "Customer left. Combo lost." The NPC leaves looking sad. | The drink in hand stays and may suit the next customer. |
| Money | **A player never loses BobaBucks.** | — |

### 3.5 Speed and accuracy scoring (**PENDING JACK: Q5** for the shape; values PROPOSED in §5.8)
`pay = round(base × grade × speed × combo × source)`, with a minimum of 1.
- **grade:** Perfect 1.0, Close 0.5.
- **speed:** Fast ×1.5 if 50% or more of the patience was left at serve, otherwise ×1.0. Scripted customers always count as Fast.
- **combo:** each consecutive **Perfect** serve adds +10%, capped at +50%. A Close or a walkout resets it. A Wrong attempt does not.
- **source:** a real-player order ×2 (plan: +100%), with the anti-farm cap in Q17.
- Feedback stacks in one toast, for example "+5 · Perfect · Fast · Combo ×3".

### 3.6 Sink, teas and water
**PENDING JACK: Q22.** Is there a sink model, and where? Or is the Ice Machine's WATER spout meant to be the water source? The coordinator corrected the brief here: "no sink exists" was never confirmed. This spec does not choose between a marker Model and Ice Machine water. Teas and Water stay off the NPC order pool until Q22 is answered. Nothing else depends on them.

### 3.7 Mobile ergonomics
- **Prompt reach:** raise `PROMPT_DISTANCE` from 6 to **8** (TUNING; the server check is already 10). M0.4 measured the natural standing spots at 6.1–6.3 studs.
- **One tap per dialog.** The size, coffee and food pickers already work this way. The button that matches the ticket pulses (M1.5d).
- **Dense prompts:** 19 syrup dispensers spread evenly across a 39-stud bar sit about 2 studs apart (39 / 20; 8 syrups would give about 4.3 studs), and Roblox shows only the nearest prompt per key. A Highlight on the right dispenser handles this for M1. The launch layout is **PENDING JACK: Q13** (fewer syrups means wider spacing, or one station with a picker).
- **Layout:** ticket and card at top left, below the Roblox top bar, at most 30% of the screen width on a phone, and collapsible to the header line. Toasts at top centre. Nothing in the bottom corners, where the thumbstick and jump button live; the existing BottomLeft clock button stays. Tap targets 44 px or larger, text 14 px or larger at phone scale (`usePx`), Styles tokens only (STYLE.md).
- Lens verifies on a phone in landscape (about 844×390) and on a tablet (M1.5e).

### 3.8 Recipe card (spec for M1.5)
Data comes from a new pure function in `OrderSpec`, so the client and tests share it:

```lua
-- One entry per step, in card order. Station = the Recipes.Items key the step uses
-- (it is also the Model name to highlight). Choice = the dialog button to pulse, if any.
export type Step = { Station: string, Choice: string?, Label: string, Optional: boolean? }
OrderSpec.Steps(spec): { Step }
-- Reads the attributes of the tool the player is holding (nil when nothing is held).
-- current = index of the first step that is not done (#steps + 1 = ready to serve).
-- problem = nil, or { Step = i, Severity = "Wrong" | "Close", Reason = "Syrup" | "Size" | ... }
OrderSpec.StepState(spec, attrs: { [string]: any }?): (current: number, problem: { any }?)
```

How each step counts as done (from the M1.1 §3 attribute table):

| Step | Done when |
|---|---|
| Clear Cup or Cup (size) | `Item` is set and `Size` is set |
| Milk | `Item == "Milk"` (or a later stage) |
| Syrup | `Item == "Flavored Milk"` (or later) and `Syrup` is set |
| Tapioca | `Item == "Boba"` |
| Coffee Machine | `Item == <coffee name>` |
| Ice | `Iced == true` |
| Sugar | `Sugar == true` |
| Mug | `Size == "Mug"` |
| Cocoa powder | `Item == "<Flavor> Hot Chocolate"` |
| Grab | `Item == spec.Item` |

A **problem** is raised as soon as an attribute that is already set disagrees with the spec. A wrong `Item` or `Syrup` is Wrong. A wrong `Size`, `Tapioca`, `Iced` or `Sugar` is Close. This uses the same severity table as `OrderSpec.Match`, so the card and the serve always agree.

What the card shows:
- **Header:** item label, a small viewport of the cup (HUD only), the patience bar, and "Shift n · k/N" (M2).
- **Rows:** ✓ done, ● current (bold, with an accent), ○ to do, ✗ or ! for a problem (red or yellow) with its reason.
- **Footer:** "Serve your customer!" once every step is done.
- The card reads the **equipped** tool only. If nothing is held, step 1 is current.

### 3.9 Station highlighting and guidance
- **Highlight** goes on the **nearest** Model under `workspace.Assets.Kitchen` whose name equals `Steps[current].Station`. Several Milk and Blender models exist, so only the nearest gets it. At the Serve step the Highlight moves to the assigned NPC. No more than 2 Highlights at once.
- **Beam** (built in code from an Attachment and a Beam, with no asset dependency) runs from the character to the target. It shows for the first 3 customers, the first time each item appears, and after 20 s idle.
- **Setting:** the existing `SyrupHighlighting` key gets the label "Station hints", **without** `MinRank`, and defaults on. The key stays the same, so no profile migration is needed. Turning it off removes the Highlights and beams. `ShiftTimerEnabled` loses its `MinRank` too (D8: no rank gating).

---

## 4. NPC customers (new `CustomerService`)

### 4.1 Lifecycle (server-owned)
`Spawning → Walking (Entry → Path → Queue) → Queued → AtCounter (assigned, waiting) → Leaving (Happy | Sad) → Exit → Destroy`.
Seating with the drink is M2 (plan §8; 243 seats exist).
- **Bodies:** the plan names `SharedStorage.NPCs.Dummy` plus `Characters` (112 HumanoidDescriptions). The M1.4a Rigger confirms the exact paths before code depends on them.
- **Movement:** `Humanoid:MoveTo` between authored nodes. **SETTLED (plan §4.3: waypoint lanes, no pathfinding).** Each segment has a 6 s timeout, after which the NPC is moved straight to the node with `PivotTo`.
- **Physics:** network owner is the server. NPCs go in an `NPC` collision group that does not collide with players, so they never block the counter. Climbing and swimming humanoid states are off.
- **Missing contract:** if the NPC nodes are missing, CustomerService warns once and disables itself. The kitchen and real-player orders keep working.

### 4.2 Arrival pacing by player count (TUNING; **SETTLED** in shape by plan §4.3, "one active NPC order per barista plus one")
- `slots` = the sum, over clocked-in baristas, of their ticket slots (1 each; a second slot comes from L5 in M2).
- `line` = 1 + floor(baristas / 4). These NPCs wait visibly in the queue.
- `target` = min(`SERVER_CAP`, `slots + line`), where `SERVER_CAP` = 16 (TUNING; M5 measures performance).
- Spawn one NPC every **3 s** or more while `present < target`. An NPC is never spawned when every queue spot is full.
- With 0 clocked-in baristas, no orders spawn and the patience of any NPC already waiting **pauses** (M2: 2 ambient NPCs who sit and wander with no orders).

| Clocked-in baristas | slots | line | NPCs present | Notes |
|---|---|---|---|---|
| 1 | 1 | 1 | 2 | The next customer is always visible in line |
| 5 | 5 | 2 | 7 | |
| 20 | 20 | 6 | 16 (cap) | About 4 baristas between tickets at any moment. Real-player orders and Rush Hour (+4 cap) fill the gap. |
| 40 | 40 | 11 | 16 (cap) | The cap binds hard. A max server size question is planned for M5 (revival-plan §11, item 5). |

Lever for high population (TUNING, M2): when `slots > SERVER_CAP`, NPC orders grow to 2 items, so each NPC carries more work.

### 4.3 Who serves which customer (**PENDING JACK: Q1**)
Recommended: **auto-assignment plus Rescue.**
- When an NPC reaches a free counter spot, it is assigned to the clocked-in barista with a free slot who has been idle longest.
- Its bubble shows that barista's name, and the ticket reaches only that barista.
- Assignment is skipped for a barista who is preparing a real-player order (`OrderService:HasActiveOrder`), and while any real-player order is pending (§4.9). Real people go first.
- **Rescue:** once a customer's patience falls below 30%, any barista may serve them. The rescuer gets normal pay plus a Rescue bonus (PROPOSED). The assigned barista's ticket clears with the toast "<name> rescued your customer!", and their combo is kept.
- If the assigned barista leaves or clocks out, the ticket goes to the next barista with a free slot. Patience keeps running.
- Alternatives Jack may prefer: a shared free-for-all queue (fast players starve newcomers in busy servers), or tap-to-claim (one extra step in minute one, and players hoard tickets).

### 4.4 Order generation (TUNING)
- Orders are built from the **assigned barista's** order pool: the L1 pool in M1, and the level pool in M2 (Q10). Generation happens at assignment time, through `OrderSpec.FromOrderItem` (**SETTLED**, M1.1 §5: one path).
- **M1 pool weights:** Classic Milk Tea Boba 55, Regular Coffee 30, Fudge Brownie 15. Sizes: Small 30, Medium 40, Large 30.
- **M2:** an item that was just unlocked gets 3× weight for its next 5 orders (the "new item" drip). Tapioca is Normal 70% of the time once other flavours are unlocked. Iced 40% and Sugar 30% once unlocked.
- Never the same spec twice in a row for one barista.
- **First session (`CustomersServed < 3`):** the orders are fixed. #1 Medium Classic Milk Tea Boba with Normal tapioca, #2 Fudge Brownie, #3 Small Regular Coffee (**PENDING JACK: Q4**).

### 4.5 Patience (TUNING)
- `patience = 45 s + per item` (Boba or Cocoa +25, Coffee or Tea +15, Grab +10). That gives a single boba 70 s, a coffee 60 s, a brownie 55 s, and boba plus brownie 80 s.
- The clock starts at **assignment**, not at spawn. It pauses for scripted customers and while no barista is clocked in.
- **Visible state** lives as NPC attributes `PatienceEnd` (server time) and `PatienceTotal`, which the bubble bar and the HUD ticket read. The bar turns yellow at 50% and red at 25%, and at 25% the NPC plays its impatient emote (if the animation exists, **Q25**).
- A practised solo boba takes about 25–30 s, so "Fast" (50% or more left, under about 35 s) rewards skill without punishing beginners.

### 4.6 Serve interaction (**PENDING JACK: Q2**, recommended: serve at the NPC)
- The prompt sits on the NPC's `HumanoidRootPart`. ActionText "Serve", HoldDuration 0, MaxActivationDistance 8, RequiresLineOfSight false (the counter is in between).
- **Client-local prompt view:** if the NPC is not yours and its patience is above 30%, the client hides the prompt (`Enabled = false` locally). Below 30% it shows "Rescue".
- **Server serve, in order:**
  1. Is the player clocked in?
  2. Distance 10 or less?
  3. NPC state is `AtCounter`?
  4. Assignment or Rescue rule passes?
  5. `OrderService:FindServeTools(player, { npc.Spec })` (M1.1 §5).
- **Perfect or Close:** destroy the tool. Pay with `CurrencyService:Modify`. `StatisticsService:IncrementStat(player, "CustomersServed")`. Send a `DialogService:Notify` toast. Show a floating "+N" BillboardGui over the NPC for 1.5 s. The NPC enters `Leaving(Happy)`.
- **Wrong:** a Notify toast with the reason text (M1.1 §5 map). The tool is kept and nothing else happens.
- All of this is synchronous with no yield between pick and destroy (M1.1 §7).
- The alternative Jack may prefer: NPCs walk to `Ordering System` Pick Up nodes and the barista deposits there, as for player orders. That reuses more of today's flow, but adds a hop and is less legible.

### 4.7 Tips and combo
See §3.5. The combo state lives on the server per player, in session memory only. It shows as "Combo ×n" in the toast, and from ×5 as a flame above the barista's head that everyone can see (M2).

### 4.8 Failure handling
- **Walkout:** the ticket is removed and the barista gets the toast "Customer left. Combo lost." The NPC plays a sad emote and walks out. No BobaBucks are taken. Cafe Rating drops (M2).
- **Stuck NPC:** a `PivotTo` fallback per segment. After 3 fallbacks in a row the NPC is despawned and its slot freed.
- **Errors:** every per-NPC step runs inside `pcall`. If one NPC errors, that NPC is despawned with a warn and the service keeps running.
- **Leaks:** NPCs are destroyed on exit, and a 10-minute soak must keep `present ≤ target` (M1.4c acceptance).

### 4.9 Real-player customers alongside NPCs
**SETTLED** (D1, plan §3): a clocked-out player is a Customer. They order at the register `Computers` through the MobileOrder UI (it exists, and TopBar attaches the register prompts). The order joins OrderService's queue.
- **M1:** player orders keep today's claim and Pick Up flow, with M1.1 auto-match. The only link to NPCs: CustomerService does not assign a new NPC ticket while any player order is pending, so a free barista picks it up.
- **M2:** player orders are auto-dispatched like NPC tickets (marked "Real customer!" with a ×2 pay badge). The customer gets the same bubble above their own head, so baristas can see them in the world. The customer gets a beam when the order is ready.
- **What a customer gets out of it** (**PENDING JACK: Q17**): they keep the drink as a holdable tool, a "Regular" stat ticks up, they make progress on a quest, and they can rate the barista with one tap out of 5 hearts after pickup, which adds to the barista's tip.
- **Anti-farm** (PROPOSED, Q17): the ×2 real-player pay applies only to a barista's first 3 orders from the same customer within 10 min.

### 4.10 Variants (M2+; **SETTLED** in concept by plan §4.3; unlock levels belong to Q10)
| Variant | Behaviour | Pay (PROPOSED) |
|---|---|---|
| VIP (from L6) | Gold bubble, patience ×0.75 | ×2 |
| Karen (from L10) | Patience ×0.5, angry emote, stomps out after a Close | ×3 on a Perfect |
| Celebrity (events only) | Uses the `Celebrity` and `CelebrityFolder` content (**Q26**) and the existing `CelebritiesMet` stat | Event reward |

---

## 5. Session and meta

### 5.1 Shift (**PENDING JACK: Q11**; recommended: count-based)
- A shift is **10 resolved customers** (served or walked out). The **first ever shift is 5**.
- It starts automatically while clocked in. Clocking out pauses it, and it is session-only (pay is already banked per serve).
- It never ends with a ticket open: the shift waits until your open tickets resolve.
- **Owner:** extend the existing `ShiftService`, which already owns the clocked-in state. Add `RecordCustomer(player, result)` and a `ShiftEnded` signal.
- The existing admin-only `ShiftTimer` button in BottomLeft becomes the "Shift k/N" readout for everyone.

### 5.2 End-of-shift card
- **Contents:** stars, customers served, BobaBucks broken down (pay, tips, shift bonus), XP gained with the bar animating, any level-up with its unlock reveal, and best combo.
- **Stars:** 3★ = no walkouts and 80% or more Perfect. 2★ = at most 1 walkout and 50% or more Perfect. 1★ otherwise. Shift bonus is PROPOSED (§5.8).
- **First shift:** a full card with "Next shift ▶" (auto after 8 s) and a secondary CTA ("See my pet" if Q15 is approved, otherwise "Capsules").
- **Later shifts:** a compact non-modal card for 6 s, so play is never interrupted. NPCs keep arriving throughout.

### 5.3 Levels and unlocks (**PENDING JACK: Q10**; recommended: no locks)
Levels widen **what NPCs order from you**, add ticket slots and customer types, and give cosmetics. Every station works at L1, and player orders can contain anything.

| Level | Unlock (PROPOSED order) |
|---|---|
| 1 | Classic Milk Tea Boba (Normal tapioca, S/M/L), Regular Coffee (hot), Fudge Brownie. This is the M1 slice. |
| 2 | Syrups: Taro, Strawberry |
| 3 | Hot Cocoa (Classic). Break areas open (Q20). |
| 4 | Macarons. Tapioca: Strawberry. |
| 5 | 2nd ticket slot. 2-item orders (drink + food). Cosmetic reward. |
| 6 | VIP customers. Iced coffee option. |
| 7 | Espresso, Cappuccino. Sugar option. |
| 8 | Syrups: Mango, Matcha. Mochis. |
| 9 | Caramel and Vanilla Hot Cocoa |
| 10 | Karen customers. Tapioca: Mystic Burst, Banana Blast. Title. |
| 12 | Americano. Ice creams. |
| 15 | Syrups: Brown Sugar, Chocolate, Passion Fruit. 3-item orders. |
| Every 5 levels | A cosmetic from the existing Nametags catalog or a title. L50 = "Boba Legend". |

### 5.4 XP (PROPOSED)
- **Per served item:** 10 XP, +5 for Perfect, +5 for Fast.
- **Per shift completed:** +10, plus 5 per star.
- **XP to go from level L to L+1:** `60 + 25·L + 2·L²`. That is 87 for L1→2, 118 for L2→3, 447 for L9→10 and 6,027 for L49→50.
- **Check against plan §4.5:**

| Plan target | Result with this curve |
|---|---|
| L2 in the first shift | 5 serves at about 17 XP plus 10 ≈ 95 |
| L10 by the end of day 1 | about 2,235 XP ≈ 12 shifts ≈ 1 h |
| L50 in about a month | about 114k XP ≈ 38 h of play |

- **New profile fields** `Level` and `XP` (plan §4.5), added through DataService reconcile. This is not destructive.

### 5.5 Quests and streaks (M4; **SETTLED** in concept, plan §4.7)
- 3 daily quests, built from stats: serve N customers, make N `<syrup>` bobas, reach a ×5 combo, clean N spills, serve a real player, rescue a teammate's customer.
- Quests are revealed after shift 2 (§2) and never before the first serve.
- A 7-day login streak with a capsule on day 7 (PROPOSED).
- The More Quests and Star Employee passes add a slot (plan §6.3).

### 5.6 Cafe Rating and Rush Hour (M2; **SETTLED** in concept, plan §3; numbers PROPOSED or TUNING)
- A server meter from 0 to 100% that starts at 50%, shown at top centre.
- **Gains and losses** are divided by `N = max(1, clocked-in baristas)`, so the meter fills in about 5–8 min of good play at any population: Perfect +4/N, Close +1/N, walkout −8/N, spill cleaned +3/N (spills depend on **Q24**).
- **At 100%: Rush Hour** for 120 s. NPC target ×1.5, `SERVER_CAP` +4, pay ×2 (PROPOSED), with music, lighting and a banner.
- Afterwards the rating resets to 60%, and there are at least 6 min between Rush Hours (TUNING).
- Points retire as a currency, and spills award XP and rating instead (**SETTLED**, plan §4.5).

### 5.7 Pets and capsules
- **SETTLED** (plan §4.5–§4.6): capsules are bought with BobaBucks, the hatch takes 15 min of active play (exists), and Skip Hatch is only valid while a hatch is pending (DEC-006).
- **The hook:** a hatch counts active play, so a capsule opened at about 2:30 keeps the new player in the game until about 17:30. That is why the free starter capsule exists (**PENDING JACK: Q15**).
- **Pet function** is **PENDING JACK: Q16**. Recommended: the equipped pet only gives a small tip boost by tier (PROPOSED: Basic +2%, Rare +4%, Epic +7%, Legendary +10%), in the same family as the tip-boost passes, where the highest value wins. Otherwise pets stay purely cosmetic, as the plan has them.

### 5.8 Economy table (every value PROPOSED, for Keeper to model and Jack to approve; M1.4 uses these only as dev placeholders if **Q6** is approved)

| Item | Proposal |
|---|---|
| Base pay | Boba 3, Coffee 2 (+1 per Iced or Sugar option), Hot Cocoa 2, Tea 2, Grab 1. A multi-item order is the sum. |
| Multipliers | Perfect 1.0, Close 0.5. Fast ×1.5. Combo +10% per step, capped at +50%. Real player ×2 (capped as in Q17). Rescue +50%. Rush Hour ×2. |
| Shift bonus | 1★ 5, 2★ 10, 3★ 15 |
| Implied rate | About 9 BB/min solo early on: Regular capsule (75) ≈ 8 min, Rare (250) ≈ 27 min, Epic (800) ≈ 85 min. That is close to plan §4.5 (Regular 10–15 min, Epic 2–3 h). Keeper should scale it. |
| Starter capsule (Q15) | 1 Regular Pet Capsule, free, at the end of shift 1 |
| Pet tip boost (Q16) | +2 / 4 / 7 / 10% by tier |
| Group member perk | +10% tips (plan §4.7) |

---

## 6. Social without chat

- **Emotes:** the Roblox avatar emote menu works without chat. Keep `CoreGuiType.EmotesMenu` enabled (verify nothing turns it off). In M4, add a 4-icon reaction wheel (heart, thumbs-up, laugh, wow) that floats an icon over your head. The Emote Pack pass adds extras (plan §6.3).
- **Co-op bonuses** (**PENDING JACK: Q18**):
  - **Rescue** (§4.3).
  - **Team Combo:** each Perfect serve anywhere in the server within 10 s of the previous one extends a server chain. At a chain of 10, everyone gets +10% pay for 60 s (PROPOSED), with a banner.
  - **Employee of the Shift:** whoever earned the most BobaBucks in the server over the last 10 min wears a crown and title until the next window.
- **Spectacle** (M2–M4): a level-up burst visible to everyone, the combo flame from ×5, Rush Hour lighting, music and confetti, happy NPCs sitting with their drinks (seating M2), "Made by <name>" on drinks handed to real players, and the in-world leaderboard boards (`LeaderboardsFolder`, plan §4.7). The server-wide "Boba Party" developer product announces the buyer on screen (plan §4.6; Jack-gated).
- **Group-event hosting** (**SETTLED** by D8 and plan §3):
  - Ranked hosts start events through Cmdr: Rush Hour, Karen Day, 2× XP for 15 min, Treasure Hunt (`ChestNodesFolder`). At most one hosted event per server every 20 min (TUNING). Each shows the banner "Hosted by <name> · <rank title>".
  - Weekly scheduled events at fixed times are announced in the group shout. They replace the trainings as the community's appointment habit.
  - Which rank numbers count as MR (moderation) and HR (hosting) is **PENDING JACK: Q20**. `RankUtil` has no thresholds, and `SettingsConfig` uses 7 as "staff".

---

## 7. Launch menu

**M1 slice (SETTLED, plan §8 M1.2):**

| Item | Spec |
|---|---|
| Classic Milk Tea Boba | Normal tapioca, S/M/L (sizes are Q3), chain per Q3 |
| Regular Coffee | Hot, no sugar, S/M/L. Iced and Sugar are off in the slice. |
| Fudge Brownie | Food Display |

For M1 the player-facing Menu stays as it is, apart from the M1.1 `ServeItem` and `Category` additions.

**Launch** (**PENDING JACK: Q12**). The NPC pool grows by level (§5.3). The player Menu lists only items that can be made.

| Category | Recommended at launch | Why |
|---|---|---|
| Boba syrups | Classic Milk Tea, Taro, Strawberry, Mango, Matcha, Brown Sugar, Chocolate, Passion Fruit (8 of the 19 wired) | Distinct colours you can tell apart at a glance, real flavours, and wider dispenser spacing (Q13). The other 11 stay wired and can return later. |
| Tapioca | Normal, Strawberry, Mystic Burst, Banana Blast (4 of 10) | Distinct colours |
| Coffees | NPCs order Regular, Espresso, Cappuccino, Americano, with Iced and Sugar. All 7 stay on the machine and the player Menu. | Decaf, Cortado and Koa look and play the same. |
| Hot Cocoa | Classic, Caramel, Vanilla | Already work (M1.1 §1) |
| Food | Fudge Brownie, 8 macarons, 5 mochis, 12 ice creams | Already work. NPCs order them as add-ons from L4. |
| Teas, Water | Off until Q22 is answered | Need the Sink step |
| Smoothies, Latte, Salted cocoa, Oolong, the other 13 pastries | Off the Menu at launch | Their recipes or tools are unconfirmed (Q19) |
| 8 Menu syrups not in Recipes | Off until Q19 is answered | Possibly cut on purpose |
| Others: Milk, Flavored Milk | Stay on the player Menu, not in the NPC pool | Harmless |
| Others: Cup | Remove | Adds nothing (M1.1) |

---

## 8. Area limiting (DEC-005; M2; **PENDING JACK: Q7, Q8, Q20**)

**What a first-session player sees and can reach** (recommended):
- **Spawn:** inside the cafe, 30 studs or less (walking) from the Clear Cup station (Q7). The camera starts facing the counter and Customer #1.
- **Open from the start ("Cafe" zone):** the kitchen, the counter and registers, the pickup area and the main hall seating.
- **Break areas** (the rooftop pool, the basement lounge, outdoors including Sakura Island, the pool and slide, and the canoes): closed by a rope or barrier and a sign reading "Break Area · opens at Level 3" until L3, which is about 10 min in (Q20). The barriers are invisible client-side parts plus a SurfaceGui sign, cloned locally while `Level < 3`. A player who slips past them reaches a pool early, which is harmless. The alternative is to leave them open from the start.
- **Out of bounds:** the far desert beyond the finished build gets permanent invisible boundary walls on the server. The Rigger proposes the line and Jack approves it (Q20).
- **Prestige spaces** (**SETTLED**, plan §4.1 and §6.3): the Office for ranked staff (approval-free cosmetic space), and the VIP lounge for the VIP and Premium Lounge passes.
- **Never deleted:** nothing is removed. Doors and barriers are additions, and OldScriptables content is moved or cloned (DEC-005).

---

## 9. Build plan (task contracts, in dependency order)

**Common rules for every code task:**
- `scripts/gate.sh <files>` must pass (no new Selene or StyLua findings, and rojo builds outside the repo).
- TestEZ runs via the `RunTests` attribute (DEC-007).
- Pure logic goes in ModuleScripts so specs can require it.
- No `.server` script logic.
- Code must not depend on any authored path until the Rigger task has named it.
- Every PROPOSED value lives in config and is commented `-- PROPOSED (Jack)`.

### M1.3: OrderSpec and serve matching (from M1.1; **no open questions**)

| ID | Role / size | Objective | write_scope | Acceptance |
|---|---|---|---|---|
| M1.3a | Mason, S | `OrderSpec` types plus `FromMenuItem`, `FromOrderItem`, `Match`, `PickTools` (M1.1 §2 and §4) | `src/shared/Ordering/OrderSpec.luau` (new), `src/server/Tests/OrderSpec.spec.luau` (new) | All 23 M1.1 cases pass in TestEZ (Gauge). The gate passes. |
| M1.3b | Mason, S | `ServeItem` data and `Category` on order items (M1.1 §2 and §6.4) | `src/shared/Ordering/Menu.luau`, `src/shared/UI/Pages/MobileOrder/init.luau`, `src/shared/UI/Pages/Ordering/init.luau` | `FromOrderItem` resolves the 3 slice items and a MobileOrder order. The gate passes. |
| M1.3c | Mason, M | Write tool attributes as the last step of each station (M1.1 §3). Blender writes nothing. | `src/server/Modules/KitchenService/Actions/SetToolAttributes.luau` (new), `.../Actions/GiveTool.luau`, `src/shared/Kitchen/Recipes.luau`, `src/shared/Kitchen/RecipeConstructors.luau` | In Studio, the slice items produce exactly `{Item=Boba,Size=Medium,Syrup=Classic Milk Tea,Tapioca=Normal}`, `{Item=Regular,Size=Small}` and `{Item=Fudge Brownie}`. A failed gate leaves the tool unmarked. Tool names are unchanged and `BobaRecipe.spec` still passes. If Q3 makes the Blender required, add `Blended=true` and a spec field instead (a delta of 1 line each). |
| M1.3d | Mason, M | `OrderService:FindServeTools`, synchronous auto-match deposit, specs in `CreateOrder`; delete `_promptToolSelection`; expose `GetPendingCount()` and `HasActiveOrder(player)` | `src/server/Modules/OrderService.luau`, `src/server/Tests/OrderService.spec.luau` | M1.1 §5. Depositing a wrong tool shows the Announcement reason and changes nothing; the correct tool sets the order to Ready. The fixture is updated. A Studio round trip works as in M0.4 §4. |

### M1.4: CustomerService MVP (blocked on **Q1, Q2, Q4, Q5, Q6, Q7, Q8**)

| ID | Role / size | Objective | write_scope | Acceptance |
|---|---|---|---|---|
| M1.4a | Rigger (Studio lease), M | Author the NPC and spawn world contract. Reuse `OldScriptables.NPCFolder` nodes where Q8 says they fit (move or clone, never destroy). | Place: `workspace.Assets.NPC.Entry` (Part), `.Exit` (Part), `.Path` (Folder of Parts `1..n`), `.Queue` (Parts `1..k`, front first), `.Counter` (Parts `1..m`, facing the kitchen). Interior SpawnLocation(s) per Q7. Confirm the paths of `SharedStorage.NPCs.Dummy` and `Characters`. Then a Quill follow-up in `docs/SYSTEMS.md`. | Captures plus a node list with positions in the evidence. The walking path from spawn to Clear Cup is 30 studs or less. Each Counter part is 25 studs or less (walking) from the Tapioca wells and the Coffee Machine. All parts are Anchored, CanCollide off and Transparency 1. A `MoveTo` walk from Entry to every Counter part succeeds in Play. |
| M1.4b | Mason, S | Config data | `src/shared/Configuration/CustomerConfig.luau` (new): cap, spawn gap, line formula constants, patience table, pay table (PROPOSED placeholders per Q6), L1 pool and weights, scripted first-session orders | Plain data. Every value is commented PROPOSED or TUNING. The gate passes. |
| M1.4c | Mason, M | Pure rules for specs: pacing target, payout calculation, patience length, assignment pick, Rescue check | `src/server/Modules/CustomerService/Rules.luau` (new), `src/server/Tests/CustomerService.spec.luau` (new) | Table tests cover §4.2 (1, 5, 20 and 40 baristas), §3.5 pay examples (the first boba = 5 with placeholder values), the Close and combo reset, and the Rescue threshold. |
| M1.4d | Mason, M | NPC lifecycle: spawn, walk, queue, counter, leave, destroy; pacing loop; collision group; `PivotTo` fallback; disable cleanly when the contract is missing | `src/server/Modules/CustomerService/init.luau` (new), `src/server/Modules/CustomerService/Npc.luau` (new) | In Studio solo: 2 NPCs present with 1 barista. 0 errors. The NPC never blocks the player. A 10-minute soak keeps the NPC count at or below target. With `workspace.Assets.NPC` renamed, there is one warn and no NPCs, and the kitchen still works. |
| M1.4e | Mason, M | Tickets and serve: assignment (Q1), order generation through `FromOrderItem`, patience attributes, the server-built bubble (BillboardGui with label, colour chip and bar), the Serve prompt, `FindServeTools`, payout, walkout, reassignment on leave or clock-out, the first-session script, and the `Client.TicketChanged` signal | `CustomerService/init.luau`, `CustomerService/Npc.luau`, `src/shared/Configuration/ProfileTemplate.luau` (add the `Statistics.CustomersServed` stat) | On a fresh profile: Customer #1 is waiting within 5 s of spawn. A Perfect serve raises BobaBucks by the config amount. A Wrong serve gives a reason toast and keeps the tool. Letting patience run out sends the NPC away sad and resets the combo. The first 3 orders match §4.4. |
| M1.4f | Mason, S | Client ticket: map `TicketChanged` onto `OrderController.CurrentOrder`, and set Serve or Rescue prompt visibility locally | `src/client/Modules/OrderController.luau`, `src/shared/UI/Components/Core/Hud/OrderTicket.luau` | The ticket shows the label and a live patience bar. It clears on serve or walkout. Another barista's NPC prompt is hidden above 30% patience (needs 2 clients; otherwise UNVERIFIED). |

### M1.5: Recipe card, highlights and mobile (blocked on **Q3, Q4**; M1.5a needs only Q3)

| ID | Role / size | Objective | write_scope | Acceptance |
|---|---|---|---|---|
| M1.5a | Mason, S | `OrderSpec.Steps` and `OrderSpec.StepState` (§3.8) | `src/shared/Ordering/OrderSpec.luau`, `src/server/Tests/OrderSpec.spec.luau` | Table tests for the 3 slice items: each step advances; wrong syrup at step 3 is Wrong; wrong size is Close; holding nothing gives current = 1. |
| M1.5b | Mason, M | The recipe card UI (§3.8), reading the equipped tool's attributes (`AttributeChanged`, `ChildAdded`/`ChildRemoved` on the character) | `src/shared/UI/Components/Core/Hud/OrderTicket.luau`, plus `src/shared/UI/Components/Core/Hud/RecipeCard.luau` (new) if OrderTicket passes about 250 lines | Ticks update within 0.2 s of a station action. Wrong and Close states display. The card collapses on a phone. Styles tokens only. |
| M1.5c | Mason, M | Station Highlight and guidance beam (§3.9); rename the setting and drop `MinRank` | `src/client/Modules/KitchenController.luau`, `src/shared/Configuration/SettingsConfig.luau` | Only the nearest matching Model is highlighted. No more than 2 Highlights. The beam shows only under the §3.9 conditions. With the setting off, nothing shows. |
| M1.5d | Mason, S | Dialog button pulse for `Steps[current].Choice`; friendly failure toasts; the server fires `InteractionFailed("ClockedOut")` on the clocked-out branch (skip that part if M1.0 already did it) | `src/client/Modules/AppDialogs.luau`, `src/client/Modules/KitchenController.luau`, `src/server/Modules/KitchenService/init.luau` | A wrong station gives the toast "Next: <label>" within 0.3 s. Clocked out gives the Clock In toast. The size, coffee and food pickers pulse the right button. |
| M1.5e | Lens, S | Mobile and tablet check | Evidence only | Captures at about 844×390 and on a tablet. Tap targets 44 px or larger. The card clears the thumbstick and jump button. Every prompt in the slice is reachable from a natural standing spot. |

### M1.6: Solo playtest (Gauge, S; after M1.3–M1.5)
Fresh profile, no group, no chat, phone emulation. Record:

| Measure | Target |
|---|---|
| Time to the first tool | ≤ 10 s |
| First drink complete | ≤ 40 s |
| **First paid** | ≤ 60 s (hard limit 90 s) |
| Customers served by 2:00 | 3 |

Also: every failure reason seen, a 10-minute soak and 0 errors. Then Jack plays it (plan M1 exit).

**M1.0 items this spec relies on:** prompt reach 6 → 8, the clocked-out toast, and wiring the trash cans if Q9 is approved.

**M2 outline** (contracts are written after Jack answers):
- `ShiftService` shifts and the end card (Q11).
- `ProgressionService` plus `Configuration/Progression.luau` for XP, Level and the order pool (Q10).
- Cafe Rating and Rush Hour (Q24).
- Area limiting (Q20).
- NPC seating and the VIP and Karen variants.
- Auto-dispatch of real-player orders and the customer bubble (Q17).
- AnalyticsService funnel (plan §4.8): joined → first tool → first serve → shift 1 → L2 → capsule → D1 return.
- Recipe book generated from `OrderSpec.Steps` (it replaces the rank-gated Staff Guide).
- Launch menu trim (Q12).
- Attribute-based station gates and hold retune (Q14).
- Starter capsule (Q15).

---

## 10. Decisions for Jack

Each question has a recommendation, and every point in the body that depends on one is marked `PENDING JACK: Q<n>`. "Blocking M1" means M1.4 and M1.5 can't be built until it is answered. M1.3 is blocked by nothing.

### Blocking M1: design
- **Q1. Who serves which NPC?** Recommend: each NPC is auto-assigned to one barista (the one with a free slot who has been idle longest), and anyone may "Rescue" it once patience is below 30%. Alternatives: a shared free-for-all, or tap-to-claim.
- **Q2. Where is an NPC served?** Recommend: the NPC stands at a counter spot beside the kitchen, and the barista taps "Serve" on the NPC. Alternative: the barista deposits at Pick Up nodes and the NPC collects.
- **Q3. Kitchen chain.** Recommend: boba = Clear Cup (size) → Milk → Syrup → Tapioca. Drop the Blender from boba (it stays usable and harmless), require Lid on nothing, and keep 3 sizes (a wrong size is Close). Alternatives: require Blender, Lid, or both, or use one size. Asset part: are the lid models meant to be named `Lid` or `Lids`?
- **Q4. First session.** Recommend: spawn inside, already clocked in. The first 3 customers are scripted (boba, brownie, coffee) with paused patience. Beam and highlights guide the player. No modal, nickname prompt or purchase prompt before shift 2. Alternative: plan §3's clock-in at the kitchen door.
- **Q5. Mistakes and money.** Recommend: never take BobaBucks. A Wrong serve keeps the tool and shows the reason. A Close pays half and resets the combo. A walkout pays nothing and resets the combo.
- **Q6. Slice payouts.** Recommend: allow the PROPOSED §5.8 numbers as dev placeholders in M1.4, so the slice pays out. You approve the real numbers at the M3 economy gate.

### Blocking M1: assets
- **Q7. Spawn.** Where should spawns go? Recommend: inside, 30 studs or less from the Clear Cup station. Is there a door or spot you want? Today's 4 spawns are outside, about 300 studs away.
- **Q8. NPC route and counter.** Which counter should NPCs line up at, and how many spots? Which door do they enter by? Are the `OldScriptables.NPCFolder` nodes (Spawn, Traversable ×16, OrderPickup, WanderPlanes) meant for the new map?
- **Q9. Trash cans.** Where are the 6 trash cans whose prompts have no handler? Is it OK to wire them as "discard held drink"?

### Later (M2+): design
- **Q10. Level rewards.** Recommend: no station or flavour locks. Levels widen what NPCs order, add a 2nd ticket slot at L5 and VIP and Karen customers, and give cosmetics every 5 levels (§5.3). Alternative: plan §4.5 tier locks.
- **Q11. Shift shape.** Recommend: 10 customers per shift (5 for the first), with a non-blocking card that auto-continues. Alternative: plan §3's timed shift.
- **Q12. Launch menu.** Recommend the §7 trim: 8 syrups, 4 tapioca, 4 coffees for NPCs, 3 cocoas, and the food display and ice cream items. Smoothies, Latte, Salted cocoa, Oolong and Cup are off.
- **Q13. Syrup bar.** Recommend: keep the walk-up dispensers. Fewer syrups give wider spacing, and the highlight shows the right one. Alternative: one Syrups station that opens a flavour picker (easier on mobile).
- **Q14. Kitchen simplification.** Recommend: switch station gates from names to attributes (so ice and sugar work in either order), and cut the Coffee Machine hold from 7 to 4 s and the Ice Machine from 5 to 3 s.
- **Q15. Starter capsule.** Recommend: a free Regular Pet Capsule at the end of shift 1, which starts a 15-min hatch that keeps the new player playing.
- **Q16. Pets.** Recommend: the equipped pet gives a small tip boost by tier (PROPOSED +2/4/7/10%). Alternative: cosmetic only.
- **Q17. Real-player customers.** Recommend: the customer keeps the drink and gets a "Regular" stat, quest progress and a 1-tap barista rating. The barista gets ×2 pay for the first 3 orders from the same customer within 10 min.
- **Q18. Co-op.** Recommend: replace plan §4.7's "split big orders" with Rescue, a server Team Combo and an Employee of the Shift crown.
- **Q19. Content gaps (asset part).** The Menu lists 8 syrups that Recipes has commented out (Banana, Avocado, Honeycomb, Almond, Mint, Orange, Blueberry, Peach). Were they cut on purpose? Do fruit and smoothie tools, and tools for the 13 unwired pastries, exist anywhere? Recommend: leave all of them off at launch unless the assets exist.
- **Q20. Area limits and ranks.** Recommend: the cafe is open from the start. The break areas (rooftop pool, basement, Sakura Island, canoes) open at L3. The far desert gets boundary walls (Rigger proposes the line). Alternative: everything open from the start. Also: which group rank numbers count as MR (moderation) and HR (event hosting)?
- **Q21. Unlimited Stock pass.** Recommend: build no restocking mechanic, and Keeper proposes a replacement perk at M3. What were the `Restocking` givers for?

### Later (M2+): assets
- **Q22. Sink.** Is there a sink model, and where? Or is the Ice Machine's WATER spout the water source? Teas and Water depend on the answer.
- **Q23. Kitchen sounds.** Where are the Sink, Pour, Machine and IceCubes sounds? The recipes ask for those names under `SFX.Kitchen`.
- **Q24. Spills.** Where are the spill models and areas? SpillService reports 4 authored paths missing, and Cafe Rating spills need them.
- **Q25. NPC and barista look.** Which existing animations should NPCs use for happy, sad and impatient? Does an apron or uniform exist? The Uniform Remover pass suggests one does.
- **Q26. Celebrity.** What is in `CelebrityFolder` and the basement `Celebrity` model, and do you still want Celebrity visits?

---

## 11. Sources
- Roblox Creator Docs, onboarding (FTUE: "get to the fun quickly", low early level thresholds, starter items, contextual teaching, funnel measurement): https://create.roblox.com/docs/production/game-design/onboarding
- Roblox Creator Docs, retention analytics (D1 retention driven by the core loop and the FTUE): https://create.roblox.com/docs/production/analytics/retention
- Work at a Pizza Place, a job sim that has run since 2008 (shared paycheck for every delivered order; job roles; coins upgrade houses; a server-wide paid pay boost): https://screenwiseapp.com/media/work-at-a-pizza-place-game
- Welcome to Bloxburg jobs (pay per task, promotions after a number of tasks, more pay at higher job levels): https://www.alphr.com/best-jobs-bloxburg/
