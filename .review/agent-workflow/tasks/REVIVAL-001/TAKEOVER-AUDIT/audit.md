# REVIVAL-001 TAKEOVER-AUDIT (read-only, branch uhweifh, HEAD efb12ff, 2026-10-21)

Scope: 54 modified + 16 untracked src files (~3.3k lines) left uncommitted after the Claude lanes hit the
rate limit. No src/ edits, commits, stashes or checkouts were made. `ActivityScript.server.luau` was not read.

## Who worked in the tree

| Window (PDT, 10-20) | Agent | Evidence |
| --- | --- | --- |
| 18:20 to ~19:40 | Claude lanes ("Mason"/"gauge", dispatched by Prime): B1-EXT verify, B4-P1, REALORDER-HEARTS, X7, S9, PATIENCE-RAMP, T5, M3-STUBS, Q6-CHAINS, H6-STREAK, B7 + B7-TIP-WIRE, TICKET-RECIPE-LINK | task summaries cite DEC-019 ("no Play/TestEZ"), the `gate.sh` WSL flow, and no Studio runs |
| ~19:40 | An interrupted Claude Code session (Jack's direct ask, not dispatched) began Titles/Staff | the Gemini 2a8e04f3 prompt pastes its transcript ("Wrote src/shared/Configuration/Titles.luau") |
| 19:49 to 20:12 | Gemini (Antigravity) `2a8e04f3` | finished Titles + Staff tab after Jack answered its questions at 19:57 |
| 19:53 to 22:02 | Gemini `29a8c6e6` ("worker", Gemini 3.8 Flash Medium) plus subagents `5610d524` (test greening + Leaderboard folder), `2ac64d46` (B4 P2/P3), `54bb9c1e` (board close-out + X10 invite), `8f796a98` (NPC tablet ordering), `fea92771` (gamepass boards), plus in-session Leaderboard displays and SHIFT-STARS-SOUND | `~/.gemini/antigravity-cli/brain/*/transcript.jsonl` and `history.jsonl` |
| 20:12 to 21:44 | Gemini `1f67e13e` plus subagents `ea2905cb` (pour minigame redesign), `d98cf1e7` (floating pour popups), `9c0653cd` (rush hour "ridiculous") | same |

No Codex sessions after 10-17. Gemini used Studio MCP heavily (execute_luau/multi_edit), so there are
**place-file edits**: 4 legacy scripts disabled (2 Fireworks dev-product scripts, the Celebrity teleporter and the
Celebrity board), boards moved to `workspace.Assets.GamepassBoards`, templates in
`ReplicatedStorage.SharedStorage.GamepassBoardTemplates`, a `StarNote` stub sound in `SoundService.SFX.UI` and
`SoundService.UISounds`. These exist only if Jack saved the place.

Jack's direct instructions to Gemini (verbatim, history.jsonl):
- 20:04: "Bypass DEC-019; delete it too. It's obsolete." Gemini then removed DEC-019 from decisions.md (the
  only change in the decisions.md diff) and ran Studio Play/TestEZ in later lanes.
- 20:20: "I approve all of this" (B4 plan, Leaderboard folder fix, test greening, X10 at 50 BB).
- 20:27: B4 seats: no animations, reuse the existing drink tools.
- 20:57 + 21:03: NPC tablet ordering flow ("1. C, 2. On the npc standing across, 3. A, dedicated").
- 20:22/20:27 (1f67e13e): pour minigame redesign choices "1. B, 2. A, 3. A, 4. B, 5. A", then "Approved".
- 20:47: replace pour toasts with rising popups. 21:32: "make rush hour spawn a ridiculous amount of customers".
- 21:34/21:41/21:44: gamepass boards, "option A" (agent maps the leftover boards), "Port the Donate! model as well".
- 21:54: leaderboard header/table fix.

## Features

### F1. BIG-B7 pour meter, Gemini redesign, and B7-TIP-WIRE
- Author: Claude Mason built B7 (PourMeter, PourMoments, KitchenController meter, tip) by 19:37 and wired the tip
  into `_onServeTriggered`. Gemini `ea2905cb` then **redesigned** it (Jack-approved): three tiers
  Perfect/Good/Poor; `InteractionRunner` now **yields inside the station sequence** on `PourMoments:AwaitPour`;
  **timeout = Poor**; Poor sets the `PoorPours` attribute, leaves the liquid 0.2 transparent, and makes
  `OrderSpec.Match` return at best **Close** (Wrong if the drink has other mistakes). Gemini `d98cf1e7` replaced
  the toasts with rising billboards.
- Maps to: BIG-B7 (dispatched), but the redesign was not dispatched (Jack via Gemini 1f67e13e).
- Completeness: done. PourMeter.spec exists and Gemini reports it green.
- Risks:
  - **Suspected P1.** `PourMoments.AwaitPour` `cleanup()` calls `task.cancel(timeoutTask)` and
    `task.cancel(walkCheckTask)`. On the timeout path and the walk-away path, `cleanup()` runs *inside* that same
    thread, so the code cancels the running thread. If Roblox errors on that (verify in Studio), the awaiting
    thread is never resumed, and `InteractionRunner._debounces[player]` stays true until rejoin. That locks the
    player out of every station. Timeout is the normal "didn't tap" path. Fix: nil the handle before cancelling,
    or skip `task.cancel` when `coroutine.running()` is that thread.
  - Design reversal: B7 said a skip or miss is neutral. Now not tapping costs grade, pay and rating on every
    SkillMoment station (Milk, Syrups, Tea powders, Hot chocolate, Coffee Machine, **Sink**). Not shown before
    the first serve (`MIN_CUSTOMERS_SERVED`).
  - Tip path: the server grades the tap (clock owned by the server, latency clamp) and the tip is read before the
    tools are destroyed inside a pcall. No new yield on the serve path. The client does not decide the reward.
- Jack-only: economy (TIP_PER_PERFECT 1, MAX 2; DEC-058 latitude, PROPOSED). Nothing else.

### F2. BIG-B4 living cafe seats
- Author: Claude built P1 (SeatingConfig, Studio stress hook). Gemini `2ac64d46` built P2/P3 (Seats.luau,
  Seats.spec, the `_run` tail, pacing subtraction).
- Maps to: BIG-B4 (dispatched). Jack approved the decisions at 20:27.
- Completeness: done but **inert**. `SeatingConfig.ENABLED = false`. It turns on only through the
  `B4SeatingForce` attribute. It uses the existing `workspace.Assets.NPC.Seats` (75 seats, verified via MCP).
- Risks:
  - Every serve clones the served drink tool onto the NPC model, even with seating off (`init.luau`
    `_onServeTriggered`). The clone keeps any scripts inside the tool. `Npc._run` reads `B4SeatingForce` without
    the `IsStudio` guard that `_seatingOn()` has, so live servers can be forced on.
  - The perf check (B4-P1 S1/S2) was never run.
- Jack-only: none.

### F3. NPC tablet ordering (core loop change)
- Author: Gemini `8f796a98`. Not dispatched: Jack asked for it via Gemini `29a8c6e6`.
- What it does: an NPC at the register shows "Hi, can I order?" and the prompt reads "Take Order". The tablet
  (`Pages.Ordering`) opens with a notepad. The server validates the submitted order with
  `Rules.ValidateSubmittedOrder` and creates the ticket for the taker (`ASSIGNMENT_MODE = "Dedicated"`). The NPC
  then walks to `Ordering System.Pick Up`, and patience starts there.
- Completeness: done for the happy path. The partial or broken parts are below.
- Risks:
  - **NPCs at the register have no patience and never walk out.** If nobody takes the order, they stand forever
    and block the counters. With F4 (cap 50, queue 35) a Rush leaves a permanent crowd behind.
  - The non-Dedicated path is broken. The "flexible" claim is false. `SetAssignment` no longer starts patience,
    and `_run` loops while `AtCounter`, so auto-assigned NPCs never time out. Clock-out `_releaseTicket` still
    calls `_assign` for AtCounter NPCs, which bypasses the tablet. AtPickup NPCs are orphaned with no ticket.
  - `_onTakeOrderTriggered` re-rolls `npc:SetOrders` on every trigger. If a second barista or a re-press hits the
    same NPC, the first tablet no longer matches.
  - `_submitNpcOrder` accepts any AtCounter NPC by Id (fallback loop) and does not re-check `_hasFreeSlot` or
    distance. Two open tablets give more tickets than the player has slots.
  - The old "Greeting" dialogue line was removed.
  - The order validation is server-side, so the client is not trusted.
- Jack-only: core design (Jack-approved). No money.

### F4. Rush Hour "ridiculous"
- Author: Gemini `9c0653cd`. Not dispatched: Jack via `1f67e13e`.
- Changes: `RatingConfig` RUSH_NPC_MULT 1.5 to 5, RUSH_CAP_BONUS 4 to 34 (50 NPCs), RUSH_MIN_TARGET 25 even with
  1 barista, spawn gap 0.2 s, burst 3 per tick, queue cap 35 (overflow NPCs stand in a line beyond the last
  queue node).
- Completeness: done.
- Risks: performance with 50 animated rigs (never measured); RUSH_PAY_MULT 2 now applies to many more
  customers (economy); the backlog never clears (see F3). `nodes.Queue[#nodes.Queue]` is nil if the Queue is
  empty.
- Jack-only: economy-adjacent (Jack asked for it directly).

### F5. Titles + Menu Staff tab
- Author: an interrupted Claude session, then Gemini `2a8e04f3`. Not dispatched: Jack's direct ask.
- Changes: `Titles.luau`, `Inventory/Titles.luau`, `Menu/Staff.luau`, ProgressionService `GrantTitle`
  (server-only) and `Client:EquipTitle` (validated, debounced), PlayerOverheads `EquippedTitle`, Menu server-info
  button hidden.
- Completeness: done. Titles.spec exists.
- Risks: profile `Titles` is written by `SetValue` but is not in ProfileTemplate (filled on join; the
  SYSTEMS.md row says so). This works, but a template row is still owed. New UI pages: check them against
  DEC-013.
- Jack-only: none.

### F6. Q6-CHAINS weekly quests
- Author: Claude Mason. Maps to: ENGAGE-QUEST-CHAINS (dispatched).
- Completeness: done. TestEZ not run in-lane; Gemini later ran the full suite.
- Changes: 3 weekly quests at 3 to 5 times the daily targets, reward 1 Regular Pet Capsule; the daily rollover
  race is fixed.
- Risks: `_ensureWeeklyQuests` assigns `playerData.WeeklyQuests = {}` on the proxy, not through SetValue, when
  the field is missing. Reconcile makes this unreachable. The weekly boundary is server-local Monday, which is
  UTC on Roblox.
- ProfileTemplate: add-only (`WeeklyQuests`, `RewardCapsule?`). No migration.

### F7. H6-STREAK shift streak
- Author: Claude. Maps to: ENGAGE-SHIFT-STREAK. Done.
- What it does: every 3rd shift in the session gives +30 BB. Clock-out does not reset it, so it is a session
  count, not a consecutive streak. Session memory only.
- Jack-only: economy number (PROPOSED).

### F8. X10 friend invite
- Author: Gemini `54bb9c1e`. Maps to: ENGAGE-FRIEND-INVITE (dispatched; Jack OK'd 50 BB).
- Completeness: done. 11 specs. A new HUD "Invite Friends" button in BottomLeft.
- Risks:
  - **Farmable.** Any join with `FollowUserId` pays the followed player 50 BB once per unique joiner. There is
    no friendship check, no account-age check, and no proof of an invite, so alt accounts can farm it.
  - `DialogService:Notify` was widened to accept `(player, title, description)`.
  - `GetDataAsync():timeout(10):await()` runs inside a task.spawn per join. Fine.
- ProfileTemplate: add-only (`InvitedFriends`).

### F9. M3-STUBS product IDs
- Author: Claude. Maps to: M3-STUBS.
- Changes: `ProductIds.luau` is all nil. Shop/Currency builds its rows from the stubs and shows live prices
  only.
- Completeness: done.
- Jack-only: product IDs are left for Jack. **No real IDs were set.** Clean.

### F10. Gamepass + Donation boards
- Author: Gemini `fea92771`. Not dispatched: Jack's direct ask.
- Changes: Studio moves plus `GamepassBoardController`.
- Completeness: done. Gemini verified it in Studio.
- Risks / **Jack-only money**:
  - The controller **hardcodes 12 real developer-product IDs** (5 to 500,000 Robux donation tiers) and calls
    `PromptProductPurchase`. `ProcessReceipt.server.luau` has no handler for them, so receipts are answered
    NotProcessedYet. Donors are charged with nothing recorded (no Top Donators credit) until Roblox refunds them.
  - Under Jack's "option A", the agent picked 5 board-to-pass mappings itself.
  - The boards prompt gamepass purchases.
  - Studio place edits (see the top section).

### F11. Leaderboard displays, folder fix, test greening
- Author: Gemini `5610d524` and `29a8c6e6`. Not dispatched: Jack's ask plus Gemini's proposal.
- Completeness: done.
- Changes: the boards resolve `workspace.Assets.LeaderboardsFolder`, with a header and a 10-row table.
- Risks:
  - KnitStart now does `workspace:WaitForChild("Assets"):WaitForChild("LeaderboardsFolder")` with no timeout.
    This replaces the old clean-disable warn.
  - To green 21 failures, the agent edited 7 spec files (ShiftService, EventService, CafeRating, PourMeter,
    Leaderboard, RecipeBookContent, DailyReward). Review that no assertion was weakened. The month key used to
    be hardcoded.

### F12. Small Claude lanes (dispatched, pre-limit)
Each one gated, TestEZ not run in-lane:
- TICKET-RECIPE-LINK: ticket item name opens Recipes focused. Done.
- REALORDER-HEARTS: the `_askHearts` call is deferred and wrapped in a pcall. Done.
- X7 Boba Party spotlight (`BobaPartyBuyer`, thank toast): done. The product ID is still nil.
- S9 Perfect sparkle (in Npc.Leave, no yield): done.
- PATIENCE-RAMP: done. With F3 the ramp now applies at pickup.
- T5 bubble focus: done.
- SHIFT-STARS-SOUND (Gemini, Studio stub sound): done.
- E-O1 / P2-1: committed in efb12ff.

### Not done (dispatched, no code found)
- BIG-B2 Cafe Upgrades, BIG-B5 Regulars, BIG-B6 Boba Pass.
- Review fixes **P2-2** (SmallNotification queue) and **P2-3** (nickname prompt; `PlayerSetup.luau` untouched).
- The P3s.

### Housekeeping
- `boba.rbxl` (3.9 MB, 19:06) sits untracked at the repo root and is not gitignored. It looks like a stray build
  or place copy: do not commit it.
- Gemini marked B4/X10/NPC-TABLET/GAMEPASS/LEADERBOARD and others done in board.json and completed.ndjson.
- decisions.md: DEC-019 was **deleted outright** (Jack-authorized). History needs a superseding entry instead.

## Gates (run by this audit)
- Selene, per changed or new src file vs HEAD (64 files, ActivityScript excluded): **0 new findings**.
  - 7 files carry baseline findings, unchanged.
  - Recipes/init went from 3 findings to 2.
- `stylua --check` on the same files: one diff, `src/shared/Kitchen/KitchenTypes.luau`. It is whole-file
  line-ending drift that HEAD's copy also fails, so it is **pre-existing**, not new.
- `rojo build default.project.json -o C:/Users/jackc/AppData/Local/Temp/audit.rbxlx`: **OK**.
- TestEZ: not run by this audit. Gemini reports the full suite at 714 pass / 0 fail after its spec edits.

## Questions for Jack (only where intent is unclear)
1. Donate board: 12 live donation product IDs prompt purchases that ProcessReceipt never grants. Should we wire
   receipts (plus Top Donators), or hide the board until then?
2. Gamepass boards "option A": confirm the agent's mapping:
   - Rainbow Pack: 29083693 (Nametag Customizer)
   - Fun Pass: 219651061 (Emote Pack)
   - Korblox: 219651161 (Water Pack)
   - Headless Head: 219651224 (Uniform Remover)
   - UnlimitedStock: 219650999 (Star Employee)
   - MopWhack: 219651106 (Flying Mop)
   - Celebrity: hidden
3. Tablet flow: should register NPCs lose patience and walk out when nobody takes their order? Today they wait
   forever, which matters with the 50-NPC rush. Is Dedicated the only mode (so the auto-assign path can be
   removed)?
4. Pour: is "no tap = Poor" (drink capped at Close, less pay and rating) intended on every pour station,
   including the Sink?
5. Friend invite: require `IsFriendsWith` and/or a minimum account age before paying 50 BB?
6. Did you save or publish the Studio edits Gemini made (disabled legacy/Fireworks scripts, moved boards,
   templates, StarNote stub)?
