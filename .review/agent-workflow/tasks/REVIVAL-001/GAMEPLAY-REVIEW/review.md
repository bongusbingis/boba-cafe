# Boba Cafe: Gameplay Review (REVIVAL-001)

**Reviewer:** gameplay / game-design review lane (read-only). **Date:** 2026-10-20. **Branch:** `uhweifh`, HEAD `c77e20c`, plus the uncommitted `RealOrderService.luau` change (M4-FIX-REALORDER-QUEST, in flight).
**Method:** everything here comes from reading source (`src/`) and the governing docs (AGENTS, CONVENTIONS, SYSTEMS, STYLE, revival-plan sections 3, 4 and 9, decisions up to DEC-051). Nothing was run: no Play, no TestEZ, no Studio (DEC-019). Timings are estimates derived from config values and are marked as estimates. Anything that depends on content authored in the place (map distances, which sounds exist under `SoundService.SFX`) is UNVERIFIED.

**Tags.** **OBVIOUS** means pure feel, juice, clarity or a bug fix that uses only existing tokens, components and patterns, with no economy, core-design or new-visual change; Prime may dispatch it without Jack. **JACK** means it touches economy numbers, prices or rewards, the core loop, roles, progression or the station/recipe flow, new content or its look, new UI tokens, components, sounds or patterns, or anything on the AGENTS.md approval list. For JACK items this review only recommends.
**Effort.** XS < 1 h, S about half a day, M 1-2 days, L more than 2 days.
**Serve-path invariant.** Every server-side feedback idea here hangs off the code *after* the payout, or off events fired after it (`CustomerResolved`, `TicketChanged` clear, `ShiftEnded`, `QuestsUpdated`). Nothing is proposed inside the guarded section of `CustomerService:_onServeTriggered` or the `RealOrderService` payout.

---

## Contents
1. Summary: top findings and the top 15 ideas at a glance
2. What is already good
3. The loop as it actually plays (first 90 s on mobile, minute 5, session 2)
4. Per-system review (findings, then ideas, each with what / why / files / effort / risk / tag)
   - 4.1 Serve moment and feedback
   - 4.2 Notifications and toasts
   - 4.3 Orders, tickets and kitchen guidance
   - 4.4 Customers (NPCs): patience, pace, reactions
   - 4.5 Onboarding and session start
   - 4.6 Progression: XP, levels, unlocks
   - 4.7 Shifts and session end
   - 4.8 Quests and daily rewards
   - 4.9 Social and co-op: Team Combo, Rush Hour, Boba Party, real orders, hearts
   - 4.10 Economy and reward pacing (JACK only)
   - 4.11 Mobile ergonomics
   - 4.12 Correctness that affects feel
5. Ideas by cost tier: Quick wins / Medium / Big bets
6. Big bets in detail (pitch, risks, dependencies, build plan, before or after release)
7. Questions for Jack (one recommendation each)
8. Suggested sequencing for the next 2-3 sessions
9. Packets written
10. Not verified

---

## 1. Summary

### 1.1 Six findings that matter most

| # | Finding | Evidence | Fix tag |
| --- | --- | --- | --- |
| F1 | **The serve toast is a blank card.** The toast component renders only `Text`, but the serve, wrong-drink, walkout and rescue toasts send `Title`/`Description` with no `Text`. Grade, combo, Fast and *why the drink was wrong* are all computed, then thrown away. | `SmallNotification.luau:238`; `CustomerService/init.luau:769,830,837,954`; also `TrashService.luau:42`, `Spill.luau:245`, `PromoCodes.server.luau:172`, `Pages/Ordering/init.luau:321`; STYLE 9.8 | OBVIOUS XS |
| F2 | **The payoff beat is silent and flat.** No sound on serve, level-up, quest, combo or Rush. The world pop-up is a static `+N` (`GREEN_DEEP`, no outline, 1.5 s). The BobaBucks number changes with no motion. | `CustomerService:_showServePay` `:866-891`; `BottomLeft.luau:396-406`; STYLE 3.10 | JACK (sounds, popup look) / OBVIOUS (pulse) |
| F3 | **Levels unlock nothing you make.** `Progression.MIN_LEVEL_BY_ITEM` is never read. `ORDER_POOL` has 3 entries (Classic Milk Tea boba, Regular coffee, Fudge Brownie), all at L1. No HUD shows level or XP, and the unlocks that do exist (L3 break area, L5 second ticket and two-item orders, L6 VIP, L10 Karen) are never announced. | `Progression.luau:19-46`; `CustomerConfig.luau:49-80`; `Hud/init.luau` | JACK (menu), OBVIOUS (callouts) |
| F4 | **Mobile tickets start collapsed.** Phones see only "Order Ticket": no steps, no item, no patience. | `OrderTicket.luau:208-209` | OBVIOUS S |
| F5 | **Two modals before the first drink, and one cannot be closed.** The Daily dialog auto-opens on join, and the nickname prompt opens at 3 s. That prompt has no close (`CloseText` is ignored) and re-prompts on an empty submit. The text says the name is permanent, and on a phone the keyboard covers the screen. | `DailyRewardController.luau:32-47`; `PlayerSetup.luau:37-73`; `TextInputPrompt.luau` | JACK S (join flow) |
| F6 | **A serve-path yield.** `QuestService:AdvanceQuest` runs synchronously inside `_onServeTriggered`, before `RecordTeamServe`, `_clearTicket` and `npc:Leave`, and it can yield. This is the same class of bug the Sentry flagged in RealOrderService. | `CustomerService/init.luau:813-815`; `QuestService.luau:63,85-92`; `M4-FIX-REALORDER-QUEST-SENTRY/review.md` P2 | OBVIOUS XS (Sentry) |

### 1.2 Top 15 ideas at a glance (ranked by value / cost)

| Rank | Idea | Tier | Tag | Effort | Risk | Packet |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Toasts render their message (F1) | Quick win | OBVIOUS | XS | Low | GAMEPLAY-TOASTS |
| 2 | Toast queue with priority; hints never overwrite gameplay toasts | Quick win | OBVIOUS | S | Low | GAMEPLAY-TOASTS |
| 3 | `AdvanceQuest` off the serve path (F6) | Quick win | OBVIOUS | XS | Low | GAMEPLAY-SERVE-QUEST-YIELD |
| 4 | Serve / level-up / combo sounds (authored in Studio, code skips if missing) | Quick win | JACK | S + Studio | Low | (after Q-G2) |
| 5 | Menu grows with level (wire `MIN_LEVEL_BY_ITEM`) | Big bet (step 1 is Medium) | JACK | M-L | Med | (after Q-G1) |
| 6 | Join flow: nickname after the first shift and skippable; Daily after the first serve | Medium | JACK | S | Low | (after Q-G3) |
| 7 | Mobile ticket: expands on a new order; collapsed header shows item + patience | Quick win | OBVIOUS | S | Low-Med | GAMEPLAY-MOBILE-TICKET |
| 8 | Level-up unlock callouts; shift card shows tips, XP to next and next unlock | Quick win | OBVIOUS | S | Low | GAMEPLAY-PROGRESS-CALLOUTS |
| 9 | Quest complete and quest claimed toasts | Quick win | OBVIOUS | XS | Low | GAMEPLAY-QUEST-NUDGES |
| 10 | HUD level pill + XP bar | Medium | JACK | M | Low | (after Q-G4) |
| 11 | Juicy `+N BB` popup (client rise and fade); Bucks counter pulse | Quick win | JACK / OBVIOUS | S | Low | - |
| 12 | Rush Hour countdown in the banner | Quick win | OBVIOUS | S | Low | - |
| 13 | NPC reacts to the outcome (Wave on serve; leaving lines by outcome) | Quick win | OBVIOUS / JACK | XS | Low | - |
| 14 | "About to leave!" warning at red patience (own customer) | Quick win | OBVIOUS | XS | Low | - |
| 15 | NPCs sit and drink after being served (243 seats, sit animations exist) | Big bet | JACK | L | Med | - |

---

## 2. What is already good

These are worth protecting while polishing.

- **No gate between join and play.** Players start clocked in (`ShiftService.DEFAULT_CLOCKED_IN`), there is no rank check (DEC-002/004), and the spawns are inside the cafe (`SpawnInterior1..4`). For a Roblox cafe RP this is the right call.
- **Customers come to you.** NPCs walk in, queue, wave and greet with a line naming the drink (`Npc._run`, `CustomerDialogue.Greeting`). They are assigned the moment they reach the counter (`_onAtCounter`), so there is no dead "waiting for assignment" time on a fresh profile.
- **The first session is scripted and forgiving.** The first 3 orders (boba, brownie, small coffee) have frozen patience and always pay the Fast multiplier (`FIRST_SESSION_ORDERS`, `Scripted`). Variants are held back while any barista is new (`_rollVariant`). The first shift is 5 customers, not 10.
- **World guidance is strong.** A gold `Highlight` sits on the next station, there is a beam for the first 3 customers, for each new item and when idle 20 s (`KitchenGuidance.ShouldShowBeam`), the size dialog pulses the right choice, "Next: <step>" appears on a wrong station, and the Serve step highlights the NPC itself. This is genuinely good onboarding.
- **Grades are forgiving.** Perfect, Close (half pay) and Wrong (rejected, drink kept, combo untouched) work well. A mistake never feels like a loss.
- **The pacing scales with players.** One barista gets 2 NPCs present and 20 get 16 (`Rules.PacingTarget`). Patience pauses when nobody is clocked in. A walkout costs only the tip, the combo and a small rating hit (plan 4.3: never punish new players hard).
- **The server has a heartbeat.** Cafe Rating leads to Rush Hour, giving a natural spike about every 6 minutes (solo, estimated). Team Combo is a shared goal. Boba Party is a social spend. Rescue lets players save each other's customers. Real-player orders pay double.
- **The retention scaffolding exists.** A 7-day streak with capsules on days 4 and 7, daily quests with reroll, a 15-minute pet hatch that only counts active play, monthly leaderboards and statues, treasure chests, scheduled events, Veteran titles.
- **The code is defensive.** Missing content degrades instead of failing (`WorldPath`, warn-once), and there are pcalls around every side effect on the serve path. That makes it safe to add feedback.

---

## 3. The loop as it actually plays

### 3.1 First 90 seconds: new mobile player, solo server (estimated)

| t | What happens (source) | Feel |
| --- | --- | --- |
| 0 s | Spawns inside; clocked in by default; uniform applied. HUD: Cafe Rating 50% at top centre; `Shift 0/5`, Clock Out, Recipe Book, Daily, **Points** (a retired currency still shown) and Bucks at bottom left. | Good start. "Points" is noise. |
| 1-3 s | The Daily dialog auto-opens (day 1 can be claimed): Claim gives +30 BB and plays `SFX.UI.Success`. | A gift before the player knows what the game is. |
| 3 s | The nickname prompt: "This cannot be changed later, so choose wisely!" There is no close, an empty submit re-prompts, and the phone keyboard covers the screen. | **Hard friction.** |
| ~3-10 s | NPC 1 spawns (3 s gap), walks Entry, Path, Queue and Counter, waves and says "Hi there! One Medium Custom Boba, please." It is assigned at once. The order is scripted with frozen patience. | Strong: a person arrives for you. |
| ~10 s | The ticket appears **collapsed** on mobile. The gold highlight and beam point at the cup station. | The world guides; the HUD says nothing on a phone. |
| ~15-45 s | The cup size dialog pulses "Medium". Then milk (3 s hold), syrup (2 s) and tapioca (1 s); the highlight hops along. | Clear but silent; no "step done" moment. |
| ~45-60 s | Done: the highlight moves to the NPC; Serve prompt (hold 0). | |
| serve | **+5 BB** (3 × 1.5 Fast). A **blank** toast slides in over 0.8 s, a static `+5` sits over the head for 1.5 s, the Bucks number goes 30 to 35 silently, and there is **no sound**. The NPC's leaving line is random and can be "Wow... Ok...". +20 XP with no feedback. | **The payoff moment is flat.** |
| 60-90 s | NPC 2 (scripted Fudge Brownie, one station) walks up within seconds. | A quick second win; good. |

Design rule 1 (drink within 60 s, paid within 90 s) is **at risk on mobile** because of the join modals and the collapsed ticket. On desktop it is probably met. Nobody has timed it in Studio.

### 3.2 Minute 5 (estimated, solo)

- **About 10 serves done.** Shift 1 (5 customers) ended at about 2.5-3 min. The `ShiftCard` appeared top right for 8 s with stars, served, "Pay: X Bonus: Y", best combo, XP and maybe "Level up! Level 2". **Tips are not shown**, so a player with a tip pass or pet never sees what it earned. The card has no next goal.
- **Level 2** (87 XP; a serve gives 10 + 5 Perfect + 5 Fast) arrives around the end of shift 1 as one toast. It unlocks nothing, and the single-slot toast lets the next serve or a 60-second legacy hint overwrite it.
- **Variety:** three recipes only. Patience is a flat 70 s for boba, 60 s for coffee and 55 s for brownie. Once the route is learned there is no tension. **This is where it starts to drag.**
- **Combo** is invisible (it lives in the blank toast). "Combo lost." is blank.
- **Rush Hour** is the good spike. Solo, a Perfect + Fast serve gives +5 rating, so 50 to 100 takes about 10 clean serves, and **Rush starts around minute 5**: 2× pay, NPCs ×1.5 for 120 s. But it has no countdown, no sound and no "ends soon" warning.
- **Team Combo** (10 serves without a walkout) fires a working toast "+10% pay for 60 seconds". The build-up is invisible.
- **Money:** 30 (Daily) + about 40 (serves) + 15 (shift stars) ≈ 85 BB, which is more than a Regular Pet Capsule (75). Nothing says so. The hints that do play are often false now ("Staff points", "Barista donation role", "automatically ranked", "Celebrity tab", "Fun Pass").

### 3.3 Session 2 (next day, about L4-6)

- The Daily auto-opens on day 2 (45 BB). This is a good beat.
- Quests regenerated, but the card is closed by default (DEC-047) with no badge. **Completing a quest gives no signal, and claiming gives no toast or sound.**
- **The orders are identical to yesterday's.** The novelty is L5 (second ticket and two-item orders: more load, no explanation), L6 VIPs and later L10 Karens. None are announced.
- The pet hatch (15 min active) is a good "stay a bit longer" timer.
- The shift target is now 10 (about 5 min). The end-of-shift card gives no "Next: Level 5 unlocks..." and no "one more shift" hook.
- At L3 the break-area gates silently disappear.

---

## 4. Per-system review

Each idea lists **What / Why / Files / Effort / Risk / Tag**.

### 4.1 Serve moment and feedback

**Findings.** Pay is computed and paid, then three weak signals fire: a toast (blank, F1), a static `+N` BillboardGui on the NPC head (`GREEN_DEEP` text, no stroke, `AlwaysOnTop`, removed after 1.5 s), and a silent counter change. No sound. The NPC's reaction is a random leaving line plus walking away. The combo multiplier exists (+10% per Perfect, cap +50%) but the player never sees it build.

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| S1 | Serve toast shows "Order served! +5 · Perfect · Fast · Combo ×3" (via F1 fix) | Teaches the grade, Fast and combo systems through reward | `SmallNotification.luau` | XS | Low | OBVIOUS |
| S2 | **Serve sound**: a coin/cash chime on the client when your ticket clears after a serve; combo raises `PlaybackSpeed` per step (×1.0 to ×1.25) | Sound is the cheapest satisfaction multiplier; rising pitch makes a streak *felt* | client (`OrderController` TicketChanged clear or a toast hook); needs **`SoundService.SFX.UI.Serve` authored by Jack/Rigger** | S + Studio | Low | JACK |
| S3 | **Juicy pay popup**: the client finds the server's `ServePay` gui under `workspace.Customers`, tweens `StudsOffset` +2 studs and fades out over 1 s; text `+N BB` in `GOLD` with the sanctioned derived stroke (STYLE 1.2) | The `+N` is easy to miss; a rising number is the genre's universal "you got paid" | new small client module or `KitchenController`; server `_showServePay` text only | S | Low | JACK (new look) |
| S4 | **Bucks counter pulse**: the Bucks `NormalButton` does a scale pop (existing `Pane` `Scale` + `SPRING_STANDARD`) when BobaBucks increases | Ties "+5" to "my money went up" | `BottomLeft.luau` | XS | Low | OBVIOUS (the existing press-scale pattern, STYLE 9.5) |
| S5 | **Count-up** of the Bucks number over 0.4 s instead of a jump | Small, classic money feel | `BottomLeft.luau` | XS | Low | OBVIOUS (it is text, but confirm with Prime that a number tick is not a "new pattern") |
| S6 | **NPC thanks you**: play the existing `Wave` track on `Leave("Served")` | The customer acknowledges you; it costs nothing | `Npc.luau` `Leave` (after payout) | XS | Low | OBVIOUS |
| S7 | **Leaving lines by outcome**: served lines vs walkout lines, using existing lines only (split in 7, Q-G6) | "Wow... Ok..." after a perfect drink undercuts the moment; Karen threatening corporate after a Perfect is wrong | `CustomerDialogue.luau`, `Npc._say` | XS | Low | JACK (content) |
| S8 | **First-ever serve celebration**: a one-time toast "Your first order! +5 Boba Bucks" plus the `Success` sound when `CustomersServed` goes 0 to 1 | Marks the onboarding milestone; the analytics funnel step 4 already exists | `CustomerService` after payout (deferred) or the client | XS | Low | JACK (sound) / OBVIOUS (text only) |
| S9 | **Perfect sparkle**: a short existing-particle burst at the NPC on Perfect (only if a particle is already authored, for example `CleanlinessStorage.Sparkles`) | Visual punctuation for quality | client | S | Low | JACK (reusing an asset for a new purpose) |
| S10 | **Combo callout at milestones**: at combo 3, 5 and 10 a bigger toast "Combo ×5! +50% pay" | Makes the streak a goal | `SmallNotification` queue + server text after payout | XS | Low | OBVIOUS |

### 4.2 Notifications and toasts

**Findings.** There is one toast slot at the bottom left (`SmallNotification`). A new push replaces the current one. The cycle is 0.8 s open, 5 s hold, about 1.25 s close. Nineteen legacy hints rotate every 60 s; many are false now. `SoundEnabled` is accepted but unused. Eight server or client call sites send payloads that render blank (F1).

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| N1 | **Text fallback**: when `Text` is nil, build it from `Title` and `Description` (`title .. ": " .. message`, the EventService precedent; no colon after `!`, `?` or `.`) | Fixes every blank toast in one place | `SmallNotification.luau` (+ STYLE 4.4, 9.8) | XS | Low | OBVIOUS |
| N2 | **Queue** (max 3, FIFO); shorter hold while something is waiting; hints dropped first | Bursts (serve + level-up + combo + quest) currently erase each other | `SmallNotification.luau` | S | Low | OBVIOUS |
| N3 | **Hint courtesy**: a hint is skipped while a toast is active or queued, or within 20 s of a gameplay toast | Stale hints currently overwrite real feedback | `SmallNotification.luau` | XS | Low | OBVIOUS |
| N4 | **Hint copy cleanup**: drop the false lines (Staff points, Barista donation role, ranked or promoted, Celebrity tab, Fun Pass, "auto hatch"); keep group, like/favourite, inventory, hatch steps, quests and explore | False advice erodes trust | `SmallNotification.luau:41-61` | XS | Low | JACK (copy about products and rewards) |
| N5 | **Toast sound** (`SoundEnabled = true` plays `SFX.UI.Pop1`) only for level-up, combo milestones and quest complete | Audio priority for the big beats | `SmallNotification.luau` | XS | Low | JACK (sound use) |

### 4.3 Orders, tickets and kitchen guidance

**Findings.** The ticket is a 190 px card at the bottom right (moving to the upper right and getting larger under DEC-050 / UI-TICKET-DAILY-MENU). It holds the recipe steps (✓ ● ○), a cup viewport, an X/Y count and a patience bar. On touch devices it starts collapsed. A step completing gives only a glyph change. Station hints are good (see section 2). The NPC bubble shows the item, flavour and patience bar, and is `AlwaysOnTop` for every barista.

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| T1 | **Expand on a new ticket** (mobile); the player can still collapse it | Phones currently hide the order | `OrderTicket.luau` | XS | Low | OBVIOUS |
| T2 | **Informative collapsed header**: the order label instead of "Order Ticket", with the existing 6 px patience bar under it | Even collapsed, you know what and how urgent | `OrderTicket.luau` | S | Low-Med | OBVIOUS |
| T3 | **Step-done tick**: a soft sound when a step completes (glyph turns ✓) | Micro-reward per action; makes the 20-30 s build feel like progress | client, `OrderTicket` attribute listener; needs `SFX.UI.StepDone` | XS + Studio | Low | JACK (sound) |
| T4 | **Fast-bonus cue**: the ticket sub-line reads "1/4 · Fast bonus!" while patience ≥ `FAST_FRACTION` (0.5) | The 1.5× Fast multiplier is the biggest pay lever and nobody knows it exists | `RecipeCard.luau` (copy), reads `CustomerConfig.FAST_FRACTION` | XS | Low | JACK (Q-G11; teaches an economy lever) |
| T5 | **Bubble focus**: on the client, hide `OrderBubble` for NPCs assigned to *other* baristas unless they can be rescued (fraction < 0.3) | At 20+ players, 16 always-on-top bubbles are a wall; rescue opportunities pop out | client (`KitchenController.updateServePrompts` already computes this) | S | Med (multi-client check) | OBVIOUS |
| T6 | **"Yours" marker** on your own NPC's bubble (gold stroke) | Instantly find your customer | client, local edit of the replicated gui | XS | Low | JACK (new visual state) |
| T7 | **Drink-in-hand preview check**: when the held tool already matches the ticket, the ticket footer turns green ("Ready! Serve your customer") (exists as `FOOTER_DONE`; T1 makes it visible on mobile) | Already built; make sure it shows | - | - | - | (covered by T1) |
| T8 | **Recipe Book link from the ticket** (tap the item name to open the page for that drink) | Mid-session lookup without hunting buttons | `OrderTicket.luau`, `Pages/Recipes` | S | Low | JACK (new interaction) |

### 4.4 Customers (NPCs): patience, pace, reactions

**Findings.** Patience is base 45 s plus a per-item bonus (boba +25, coffee or tea +15, grab +10). It starts at assignment, has no difficulty ramp except variants (VIP 0.75× patience from L6, Karen 0.5× from L10), and multi-item orders sum their bonuses. A walkout gets a leaving line, a combo reset and -2 rating. Solo, the next NPC is usually already queued, so the dead time between serves is short (a few seconds of walking to the counter).

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| C1 | **About-to-leave warning**: when your own customer drops to red (≤ 25%), one toast "Your customer is getting impatient!" (once per NPC) | Urgency right when it matters; prevents surprise walkouts | client (`OrderTicket`'s patience effect) or `KitchenController` | XS | Low | OBVIOUS |
| C2 | **Impatience reaction**: the NPC plays `Confused` once at yellow, and the bubble patience bar is already coloured | Customer body language instead of UI-only urgency | `Npc._waitOutPatience` (server, not on the serve path) | XS | Low | OBVIOUS (existing animation; Karen-only "stomp" precedent) |
| C3 | **Rescue broadcast**: when an unassigned or other barista's NPC becomes rescuable, clocked-in baristas within 40 studs get "A customer needs help! Rescue for 1.5× pay" (throttled to once per 20 s) | Turns Rescue into a visible co-op moment; teaches the mechanic | client | S | Low | OBVIOUS |
| C4 | **NPCs sit and drink after a serve** (243 seats; `BoothSit`, `CafeSit`, `ComfySit` and `CouchSit` exist in `NPCStorage.Animations`); they leave after 20-40 s | A full cafe is the fantasy; the room fills with your work. Big bet B4 | `Npc.luau`, `CustomerService` (seat reservation); authored seats | L | Med (perf, pathing) | JACK |
| C5 | **Regulars**: a small chance an NPC is a named regular who remembers you ("Back again! The usual?") | Emotional hook, a collection angle. Big bet B5 | new data | L | Med | JACK |
| C6 | **Patience ramp by shift**: shift 3+ of a session trims patience by 5-10% | Raises tension as skill rises | `Rules.PatienceSeconds` | XS | Med | JACK (core pacing) |

### 4.5 Onboarding and session start

**Findings.** F5. There is also a stray `print(textRef.current)` in `TextInputPrompt.luau:49`. The scripted first 3 orders and the guidance are good. Two dialogs compete in the first seconds (stacking behaviour UNVERIFIED).

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| O1 | **Nickname after the first shift**, with Skip (keeps `DisplayName`; still once per profile) | Design rule 1; revival plan 4.1 already says this | `DataService/PlayerSetup.luau`, `Dialogs/TextInputPrompt.luau` | S | Low | JACK (join/play flow) |
| O2 | **Daily after the first serve** for profiles with `CustomersServed == 0` | The gift lands better after the first success; the first screen becomes play | `DailyRewardController.luau` | XS | Low | JACK |
| O3 | **Welcome line**: a one-time toast at clock-in for a new profile, "Welcome to Boba Cafe! Follow the gold glow to make your first drink." | One sentence of framing; chat-free | client | XS | Low | OBVIOUS |
| O4 | **Remove the stray `print`** in `TextInputPrompt.luau:49` | Output noise | `TextInputPrompt.luau` | XS | None | OBVIOUS |
| O5 | **Hide Points** on the HUD (plan 4.5 retires Points as a currency) | One less meaningless number | `BottomLeft.luau` | XS | Low | JACK (already in plan; confirm) |

### 4.6 Progression: XP, levels, unlocks

**Findings.** F3. XP per serve is 10 per item + 5 Perfect + 5 Fast; shift XP is 10 + 5 per star; quests give XP. The curve is `60 + 25L + 2L²`: L2 ≈ 5 serves, L3 ≈ 10, L5 ≈ 25 (about 12-15 min). That curve is good. The problem is that nothing *changes* except load (second ticket, multi-item orders) and the occasional nametag. The title changes every 5 levels (overhead only).

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| P1 | **Level-up callouts** name what opened, read from config: title, ticket slots, items per order, VIP/Karen, nametag | Every level-up tells a story; short-term goals become visible | `ProgressionService._onLevelUp` | XS | Low | OBVIOUS |
| P2 | **Break areas open** toast when the level crosses 3 during play | Explains the gates retroactively | `AreaController.luau` | XS | Low | OBVIOUS |
| P3 | **Shift card progress lines**: "Level 3 · 40/170 XP" and "Next: Level 5 · 2 order tickets" | A "one more shift" hook on the session-end screen | `ProgressionService` (ShiftEnding listener), `ShiftCard.luau` | S | Low | OBVIOUS |
| P4 | **HUD level pill + XP bar** above the Shift pill (CafeRating Track/Fill/Banner primitives), filled from the replicated profile `XP`/`Level` with `SPRING_STANDARD` | The strongest constant pull; every serve visibly moves it | new `Hud/LevelBar.luau`, `BottomLeft.luau` | M | Low | JACK (new HUD element, Q-G4) |
| P5 | **Menu grows with level** (wire `MIN_LEVEL_BY_ITEM`) | Real payoff per level; variety beats boredom. Big bet B1 | `CustomerConfig.ORDER_POOL`, `Menu.LAUNCH_ITEMS` | M-L | Med | JACK (Q-G1) |
| P6 | **Level-up moment**: the level-up toast gets the `SFX.UI.Success` sound, plus a gold flash on the HUD level pill (with P4) | The level-up should be the best feeling in the game | client | XS | Low | JACK (sound) |
| P7 | **Drink mastery stars**: serving N Perfects of a drink gives it bronze, silver and gold stars in the Recipe Book | Long-tail goals per recipe. Part of B1 | profile field, Recipe Book | M | Low | JACK |

### 4.7 Shifts and session end

**Findings.** Shifts are count-based (5 on the first, then 10). Stars come from the walkouts and Perfect ratio. The bonus is 5 BB per star. The card is non-blocking, top right, auto-hides after 6-8 s, and has no buttons. The pay line hides tips, and walkouts are not shown. The next shift starts silently. Real-player serves do not count toward the shift (only `CustomerResolved` feeds `RecordCustomer`).

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| H1 | **Card rows**: stars; "Served 10 · Walkouts 1"; "Pay 40 · Bonus 15 · Tips 5"; best combo (if ≥ 2); "XP +120 · Level 3 (40/170)"; "Next: Level 5 · 2 order tickets" (max 6 rows so the card does not overflow) | Visible perks (tips) support monetization; a next goal hooks the next shift | `ShiftCard.luau`, `ProgressionService` | S | Low | OBVIOUS |
| H2 | **Star jingle** on the card (1-3 rising notes) | The session-end moment deserves audio | client; needs authored sounds | XS + Studio | Low | JACK |
| H3 | **Personal bests**: "New best combo!" / "Best shift ever!" lines with a stored best | Self-competition, cheap | profile fields (`ProfileTemplate` add = safe), `ShiftService` | S | Low | JACK (new profile fields) |
| H4 | **Shift-end CTA** ("Open a capsule" when affordable) as one `PromptButton` on the card, or a toast | The plan's "Next shift / Open a capsule" CTA; converts BB into the meta loop | `ShiftCard.luau` or toast | S | Low | JACK (monetization nudge, Q-G8) |
| H5 | **Real-player serves count** toward the shift N | A shift with real customers should feel like progress too | `RealOrderService` after payout → `ShiftService:RecordCustomer` | XS | Med | JACK (Q-G10) |
| H6 | **Shift streak**: 3 shifts in a row in one session gives a bonus chest or XP | Directly targets average session length (≥ 12 min goal) | `ShiftService`, config | S | Low | JACK (economy) |

### 4.8 Quests and daily rewards

**Findings.** Quests: 3 slots (+1 with a pass), types Boba, Served, Spills, RegularOrders and Shifts, a 20 BB reroll, and a closed-by-default pop-up card. Completion and claim are silent. Daily: a 7-day streak with capsules on days 4 and 7, auto-opened on join when claimable, with the `Success` sound on claim.

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| Q1 | **Quest complete toast** "Quest complete: Serve 5 customers! Open Quests to claim." (deferred, once per flip) | The card is closed; this is the only way players learn | `QuestService.AdvanceQuest` | XS | Low | OBVIOUS |
| Q2 | **Quest claimed toast** "+30 Boba Bucks · +20 XP" from the entry's own reward fields | Reward confirmation | `Hud/QuestCard.luau` | XS | Low | OBVIOUS |
| Q3 | **Quest progress pings** at halfway ("Serve 5 customers: 3/5") | Micro-goals mid-shift | `QuestService` | XS | Low | OBVIOUS (but watch toast volume; only after N2) |
| Q4 | **Claimable dot** on the Quests button | Standard affordance | `BottomRight.luau` | XS | Low | JACK (new visual, excluded in M4-QUESTS-REDO) |
| Q5 | **Streak-at-risk reminder** via `ExperienceNotificationService` opt-in (plan 4.7) | D1/D7 retention | new service | M | Low | JACK |
| Q6 | **Quest chains / weekly quests** (bigger targets, a capsule reward) | A medium-term goal between the daily and the monthly leaderboard | `QuestConfig`, `QuestService` | M | Med | JACK (economy) |

### 4.9 Social and co-op: Team Combo, Rush Hour, Boba Party, real orders, hearts

**Findings.** Team Combo: 10 serves server-wide give +10% for 60 s, a toast only, chain invisible (DEC-036 C5). Rush Hour: a banner change, no timer. Boba Party: cannot be bought yet (product id `nil`). Real orders: x2 pay for the first 3 from the same customer, then a hearts rating (1-5 plain buttons). The barista is never told the result.

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| X1 | **Rush countdown**: the server publishes `RushEndsAt`; the banner reads "Rush Hour! 1:24" | Urgency, and players stay to the end | `CafeRatingService.luau`, `Hud/CafeRating.luau` | S | Low | OBVIOUS |
| X2 | **Rush start fanfare** (sound + toast "Rush Hour! 2× pay for 2 minutes!"; the toast already exists, the sound needs authoring) | Peak excitement beat | client; `SFX.UI.Rush` | XS + Studio | Low | JACK (sound) |
| X3 | **Team chain progress** appended to the serve toast from 5/10 ("Team 7/10") | Makes the co-op goal visible | `CustomerService` toast text (after payout) | XS | Low | JACK (amends DEC-036 C5, Q-G7) |
| X4 | **Combo MVP**: when a Team Combo triggers, the toast names the barista who served the 10th ("Ana completed the Team Combo!") | Social credit at zero cost | `CustomerService.RecordTeamServe` | XS | Low | OBVIOUS (text on an existing announcement) |
| X5 | **Hearts to the barista**: "Alex gave you 5 hearts!" | Social payoff for serving real people | `RealOrderService._askHearts` (async, after payout); **after M4-FIX-REALORDER-QUEST commits** | XS | Low | OBVIOUS |
| X6 | **Heart icons on the rating buttons** (instead of "1"-"5") | Already an open question for Jack | `RealOrderService` | XS | Low | JACK (open) |
| X7 | **Boba Party spotlight**: the buyer's name in a top-centre banner during the party (existing Banner) and a thank-you emote prompt | Social spend should feel celebrated; drives repeat purchases | `CafeRating.luau` banner text | S | Low | JACK (monetization presentation) |
| X8 | **Co-op big orders** (a 4-6 item party order two baristas split, bonus on completion) | Plan 4.7. Big bet B3 | `CustomerService`, tickets | L | Med-High | JACK |
| X9 | **Emote / reaction wheel** (chat-free expression) | Plan 4.7; social RP without chat | new UI | M | Low | JACK |
| X10 | **Friend invite reward** (`SocialService:PromptGameInvite`) | Plan 4.7; CCU growth | new | S | Low | JACK (reward) |

### 4.10 Economy and reward pacing (all JACK; only observations)

- Serve pay averages about 4 BB (boba Perfect Fast 5, coffee 3, brownie 2), plus the shift bonus of 5 per star. The first capsule (Regular Pet, 75) is reachable around minute 5 thanks to the day-1 Daily of 30. **That pacing is good.** The missing piece is telling the player (H4, Q-G8).
- Fast (1.5×) is worth more than the whole combo cap (+50%), yet it is invisible (T4).
- Rescue (1.5×) is a good co-op incentive that nobody is told about (C3).
- Close pays half. Combined with "Combo lost" being invisible, players cannot tell a Close from a Perfect except by the number (S1 fixes this).
- Real orders pay x2 only for the first 3 per customer per 10 min. This is sensible anti-farm; no change proposed.
- **No change to any number is proposed here.**

### 4.11 Mobile ergonomics

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| M1 | Ticket expanded and informative (T1, T2) | Main platform clarity | `OrderTicket.luau` | S | Low-Med | OBVIOUS |
| M2 | **Toast vs thumbstick**: the toast lives in the bottom-left stack (135 px tall) over the left thumbstick zone (0-0.3 width, bottom 45%). Lens should capture at 844 × 390 and confirm it does not intercept touches (`Active` false) | A toast that blocks movement during a serve burst would be awful | `SmallNotification.luau` (verify only) | XS (capture) | Low | OBVIOUS (verification) |
| M3 | Serve prompt range: `MaxActivationDistance 8`, server check 10 studs, `HoldDuration 0`. That is good for phones. Keep it. | - | - | - | - | - |
| M4 | **Bottom-left stack height**: Clock Out sits in the main stack and one mistap clocks you out mid-shift (the shift resets: `_states[player] = nil`). A confirm via `ButtonPrompt` ("Clock out? Your shift progress resets.") | Prevents a frustrating accidental loss | `BottomLeft.luau` | XS | Low | OBVIOUS (existing dialog type) |
| M5 | Nickname prompt keyboard (O1) | - | - | - | - | JACK |

### 4.12 Correctness that affects feel

| ID | What | Why | Files | Effort | Risk | Tag |
| --- | --- | --- | --- | --- | --- | --- |
| K1 | `AdvanceQuest` in `task.spawn` on the NPC serve path (F6) | Invariant; double-serve window; delays `RecordTeamServe` | `CustomerService/init.luau:813-815` | XS | Low (Sentry) | OBVIOUS |
| K2 | `ShiftCard` hides `Tips` (the computed field is never rendered) | Paid perk invisible | `ShiftCard.luau:34-51` | XS | Low | OBVIOUS (in H1) |
| K3 | `QuestService.ClaimQuest` calls `AddXp` and `Modify` inside a pcall after a possible yield. That is fine, but the claim gives no client signal (Q2) | - | - | - | - | - |
| K4 | `Npc.Leave` picks a random line for *every* leave reason, including served (S7) | - | - | - | - | JACK (content) |

---

## 5. Ideas by cost tier

### 5.1 Quick wins (XS-S; most can ship this week)

| ID | Idea | Tag |
| --- | --- | --- |
| N1 / S1 | Toast text fallback (fixes every blank toast) | OBVIOUS |
| N2 / N3 | Toast queue; hint courtesy | OBVIOUS |
| K1 | Serve-path quest yield | OBVIOUS |
| T1 / T2 | Mobile ticket expand + informative header | OBVIOUS |
| P1 / P2 / P3 / H1 | Level-up callouts, break-area toast, shift card progress and tips | OBVIOUS |
| Q1 / Q2 | Quest complete / claimed toasts | OBVIOUS |
| S4 / S5 | Bucks pulse / count-up | OBVIOUS |
| S6 | NPC Wave on serve | OBVIOUS |
| S10 | Combo milestone callouts | OBVIOUS |
| C1 / C2 / C3 | Impatient warning, impatience reaction, rescue broadcast | OBVIOUS |
| X1 / X4 / X5 | Rush countdown, Team Combo MVP name, hearts to the barista | OBVIOUS |
| M4 | Clock-out confirm | OBVIOUS |
| O3 / O4 | Welcome line, remove the stray print | OBVIOUS |
| S2 / T3 / H2 / X2 / P6 / N5 | Sounds: serve, step, stars, rush, level-up, toast | JACK (Studio authoring) |
| S3 | Juicy `+N BB` popup | JACK (look) |
| S7 / N4 | Leaving lines by outcome; hint copy cleanup | JACK (content/copy) |
| T4 / X3 / X6 / T6 / Q4 | Fast cue, team chain count, heart icons, "yours" marker, quest dot | JACK |
| O1 / O2 / O5 | Join flow, Daily timing, hide Points | JACK |

### 5.2 Medium (S-M; one session each)

| ID | Idea | Tag |
| --- | --- | --- |
| P4 | HUD level pill + XP bar | JACK |
| T5 | Bubble focus (multi-client) | OBVIOUS |
| H3 / H6 | Personal bests; shift streak bonus | JACK |
| H4 | Capsule-affordable CTA | JACK |
| Q5 / Q6 | Streak reminder notifications; weekly quests | JACK |
| X7 / X9 / X10 | Boba Party spotlight; emote wheel; friend invite reward | JACK |
| P5 step 1 | First 4 level-gated menu items (B1 phase 1) | JACK |
| T8 | Recipe Book link from the ticket | JACK |

### 5.3 Big bets (L; new mechanics or meta, see section 6)

| ID | Big bet | Tag | Before or after release |
| --- | --- | --- | --- |
| B1 | Menu progression and drink mastery | JACK | **Before** (phase 1); mastery after |
| B2 | Cafe upgrades (a server-visible decor sink) | JACK | After |
| B3 | Co-op party orders | JACK | After (first update) |
| B4 | Living cafe: NPCs sit, drink and react | JACK | Phase 1 before if perf allows; else first update |
| B5 | Regulars collection (named NPCs who remember you) | JACK | After |
| B6 | Seasonal Boba Pass (free + premium track on XP) | JACK | After (needs retention data) |
| B7 | Station skill moments (a perfect-pour timing tap) | JACK | After, behind playtest |
| B8 | Celebrity visits / VIP boss customers (Celebrity folder and `CelebritiesMet` stat exist) | JACK | After |

---

## 6. Big bets in detail

### B1. Menu progression and drink mastery
- **Pitch:** every few levels a new drink joins the order pool (Taro, Strawberry, Hot Cocoa, Mango, Espresso...). The Recipe Book shows locked drinks with "Unlocks at Level N". Later each drink earns bronze, silver and gold mastery stars from Perfect serves.
- **Why:** fixes F3. Variety is the main thing between minute 5 and session 10. It gives every level-up content and creates a visible ladder of goals.
- **Data already in place:** `Progression.MIN_LEVEL_BY_ITEM` (26 entries), `Rules.PickOrder` already filters `MinLevel`, `CustomerConfig.ITEM_COUNT_BY_LEVEL`, `Menu.IsLaunchItem`, the `OrderSpec.Steps` guidance, `PAY_TABLE` per category.
- **Risks:** a recipe that does not work end to end at the authored givers would strand players (revival plan 4.2 "Reconcile the content"); M0.4 saw boba recipes broken at one point. Pool weights could drown the classic drinks. Each new syrup needs its dispenser and colour chip.
- **Dependencies:** Jack's item list (Q-G1), a Keeper pass on weights, a per-recipe Studio run by Jack, a Recipe Book locked state (a new visual, Jack).
- **Rough plan:** (1) Architect: for each candidate item, confirm the giver, recipe and `OrderSpec` chain from source plus a Jack Play check. (2) Mason: `ORDER_POOL` entries with `MinLevel` from `MIN_LEVEL_BY_ITEM`; `LAUNCH_ITEMS` updated; specs for `PickOrder` by level. (3) The P1 callout names the new drink. (4) Phase 2: mastery stars (profile field `Mastery[item]`, increment on Perfect after payout, Recipe Book display).
- **Recommendation:** phase 1 (4-6 items up to L8) **before release**. It is the single biggest retention lever. Mastery after release.

### B2. Cafe upgrades
- **Pitch:** spend BobaBucks on cafe improvements (plants, lights, a bigger tip jar, a music jukebox) that everyone in the server sees, with the contributor's name on a plaque.
- **Why:** a non-pet BB sink, a social status display, and server pride.
- **Risks:** persistence model (per server is ephemeral; per player only shows in your own view; a global DataStore has contention). Builds on the place file (Rigger). New content look.
- **Dependencies:** a decision on persistence; authored upgrade models; economy pricing.
- **Plan:** a prototype of 3 upgrades per server session (resets on server close) to test appeal, then decide on persistence.
- **Recommendation:** **after release**, once the BB sink data shows players hoarding.

### B3. Co-op party orders
- **Pitch:** occasionally a group NPC arrives with a 4-6 item party order. Any baristas can contribute items. On completion everyone who contributed gets a bonus and a shared "Party served!" moment.
- **Why:** "better at 40". A co-op beat that does not need chat.
- **Risks:** ticket model changes (shared ticket across baristas), serve-path complexity (multiple tools from multiple players), griefing.
- **Dependencies:** a ticket architecture change (Architect); a Sentry review on the payout.
- **Plan:** a server "PartyOrder" entity with per-item claims; each item served at the NPC through the existing auto-match; payout after the last item, split by contribution.
- **Recommendation:** **after release** (first content update), with a Team Combo tie-in.

### B4. Living cafe: NPCs sit and drink
- **Pitch:** served customers carry their drink to a free seat, sit (BoothSit, CafeSit, ComfySit, CouchSit animations exist), drink for 20-40 s, maybe react with a heart emote, then leave.
- **Why:** the cafe looks busy and alive, the player sees the result of their work, screenshots and thumbnails improve.
- **Risks:** NPC count and performance (more NPCs present: `SERVER_CAP` is 16 for waiting NPCs); seat pathing with `MoveTo` (fallback `PivotTo` exists); seats taken by players.
- **Dependencies:** an authored seat contract (Rigger names the seat folder; 243 seats exist per the plan, but the paths must be confirmed, per DEC-008); NPC-LOOK for the drink prop.
- **Plan:** a separate "seated" NPC budget (for example 8), the nearest free seat from an authored `workspace.Assets.NPC.Seats` folder (Rigger), and leave after a timer. Never block the counter flow.
- **Recommendation:** phase 1 **before release only if** a Studio perf check is clean; otherwise in the first update.

### B5. Regulars collection
- **Pitch:** a set of named regulars (for example 12) with fixed looks and favourite drinks. They appear now and then, greet you by name after the first time, and fill a "Regulars" page with stamps.
- **Why:** collection plus a sense of relationship; "I want to meet the last regular" brings players back.
- **Risks:** content authoring (looks, names: Jack); profile data (a stamp table).
- **Recommendation:** **after release.**

### B6. Seasonal Boba Pass
- **Pitch:** a 30-day track (free + premium) on XP earned, with nametags, particles, a pet and an exclusive cup skin.
- **Why:** proven retention and monetization in Roblox; uses the existing XP stream and cosmetic catalog.
- **Risks:** catalog content; pricing; requires a reliable XP display (P4) first.
- **Recommendation:** **after release**, once D1 and D7 data exist.

### B7. Station skill moments
- **Pitch:** an optional timing tap on the pour stations (stop the meter in the green for a "perfect pour" that adds to the tip).
- **Why:** skill expression and juice.
- **Risks:** it changes the station/recipe flow (core); a mobile tap-target; it can slow down new players.
- **Recommendation:** **after release**, A/B behind a setting, only if session data shows boredom with holds.

### B8. Celebrity visits
- **Pitch:** rare celebrity NPCs (the `CelebrityFolder` and `CelebritiesMet` stat exist) with a server-wide announcement, a big tip and a badge.
- **Why:** spectacle and "you had to be there" moments, which helps CCU.
- **Risks:** content (looks); badge ids.
- **Recommendation:** **after release**, as an event in `EventService`.

---

## 7. Questions for Jack

| Q | Question | Recommended |
| --- | --- | --- |
| Q-G1 | Wire `MIN_LEVEL_BY_ITEM` so levels add drinks (B1 phase 1)? | **Yes.** Start with L2 Taro and Strawberry syrup, L3 Hot Cocoa Classic, L4 Strawberry tapioca, each only after a working end-to-end recipe. |
| Q-G2 | Author sounds `SoundService.SFX.UI.Serve` and `SoundService.SFX.UI.LevelUp` (then `Combo`, `StepDone`, `Rush`)? Meanwhile, reuse `SFX.UI.Success` for level-up and quest claim? | **Yes to both.** |
| Q-G3 | Nickname prompt after the first shift with Skip (keeps DisplayName); Daily auto-open after the first serve for new profiles? | **Yes.** |
| Q-G4 | HUD level pill + XP bar above the Shift pill, built from CafeRating primitives? | **Yes.** |
| Q-G5 | Client `+N BB` popup that rises and fades, `GOLD` with the derived stroke? | **Yes.** |
| Q-G6 | Leaving lines by outcome (served: "Cya later!", "Goodbye!", "Bye!", "Thanks, see ya!", "Later!", "I'm out, have a good one!"; walkout: "Wow... Ok..."; Karen after a Perfect uses the default served lines)? | **Yes.** |
| Q-G7 | Show the Team Combo chain ("Team 7/10") in the serve toast from 5/10 (amends DEC-036 C5)? | **Yes.** |
| Q-G8 | "You can afford a capsule" nudge once per session (price read from the capsule definitions)? | **Yes**, as a toast first. |
| Q-G9 | Hint copy cleanup (drop the false lines listed in N4)? | **Yes.** |
| Q-G10 | Real-player serves count toward the shift N? | **Yes.** |
| Q-G11 | "Fast bonus!" cue on the ticket while patience ≥ 50%? | **Yes.** |
| Q-G12 | Hide the Points button on the HUD (plan 4.5)? | **Yes.** |
| Q-G13 | B4 living cafe before release, subject to a Studio perf check? | **Yes, if perf allows**; otherwise the first update. |

---

## 8. Suggested sequencing (next 2-3 sessions)

**Session 1 (now; no Jack needed except for the questions):**
1. GAMEPLAY-SERVE-QUEST-YIELD (Mason XS + Sentry), in parallel with
2. GAMEPLAY-TOASTS (Mason S; client only). This alone makes every serve readable.
3. GAMEPLAY-QUEST-NUDGES (after TOASTS so its toasts queue).
4. Prime batches Q-G1 to Q-G13 to Jack in one message. Jack authors `SFX.UI.Serve` and `LevelUp` in Studio if he says yes.
5. Jack Play test: the serve toast reads correctly, toasts queue, a quest complete toast appears, and serving twice to one NPC is impossible.

**Session 2 (after UI-TICKET-DAILY-MENU lands):**
1. GAMEPLAY-MOBILE-TICKET (+ Lens re-capture of the moved ticket expanded on 844 × 390).
2. GAMEPLAY-PROGRESS-CALLOUTS (ShiftCard rows, level-up callouts, break-area toast).
3. Quick wins that need new packets: S4 Bucks pulse, S6 Wave, C1 impatient warning, X1 Rush countdown, X5 hearts toast (after M4-FIX-REALORDER-QUEST is committed), M4 clock-out confirm.
4. If Q-G2 = yes: the sounds packet (client lookups with skip-if-missing; serve, level-up, combo pitch).

**Session 3 (bigger):**
1. B1 phase 1 (if Q-G1 = yes): an Architect recipe audit, then Mason pool entries.
2. P4 XP bar (if Q-G4 = yes), S3 pay popup (if Q-G5 = yes), O1/O2 join flow (if Q-G3 = yes).
3. A first-session timing playtest by Jack on a phone: time to first drink and first payout against design rule 1, recorded as evidence.

---

## 9. Packets written

In `.review/agent-workflow/tasks/REVIVAL-001/packets/`:
- `GAMEPLAY-TOASTS.md`: N1-N3 (client, `SmallNotification.luau`).
- `GAMEPLAY-SERVE-QUEST-YIELD.md`: K1 (server serve path; Sentry).
- `GAMEPLAY-MOBILE-TICKET.md`: T1, T2 (`OrderTicket.luau`; after UI-TICKET-DAILY-MENU).
- `GAMEPLAY-PROGRESS-CALLOUTS.md`: P1-P3, H1 (`ProgressionService`, `ShiftCard`, `AreaController`).
- `GAMEPLAY-QUEST-NUDGES.md`: Q1, Q2 (`QuestService`, `QuestCard`).

## 10. Not verified

- Walk distances, station layout and the real time to first serve: not measured (needs Jack in Play).
- Which sounds exist under `SoundService.SFX.UI`: M0.4 found `SFX.UI` missing. Whether Pop1, Pop2 and Success exist now is unknown.
- How the Daily dialog and the nickname prompt stack: unverified.
- Whether the toast frame intercepts touches over the thumbstick: unverified (M2).
- The `QuestService._getPlayerData` `await` on a loaded profile may not yield, but the day-rollover `_hasPass` / `PlayerOwnsPassAsync` path can on a cold cache.
- Seat paths for B4 and the Celebrity content for B8: named in the plan, not verified in the place (DEC-008: the Rigger confirms them before any build).
