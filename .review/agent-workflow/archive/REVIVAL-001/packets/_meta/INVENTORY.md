# INVENTORY (REVIVAL-001 packet generation, HEAD 098175c)

Paths are relative to `src/` unless noted. Verified with Grep/git ls-files at HEAD. Tiers: H = haiku-ok, S = sonnet, O = opus. Gate: B = before release, A = after.
Merged packets take the highest tier of their ideas. Routing exceptions caused by merging are marked (*).

## (a) ID -> packet table

| ID | Packet | Owning files (verified) | Tier | Gate |
|---|---|---|---|---|
| S4 | HUD-BOTTOMLEFT | shared/UI/Components/Core/Hud/BottomLeft.luau | H | B |
| S5 | HUD-BOTTOMLEFT | BottomLeft.luau | H | B |
| O5 | HUD-BOTTOMLEFT | BottomLeft.luau | H | B |
| M4 | HUD-BOTTOMLEFT | BottomLeft.luau (+ read Dialogs/ButtonPrompt.luau) | H | B |
| P4 | HUD-LEVELBAR | NEW Hud/LevelBar.luau, BottomLeft.luau, Hud/init.luau (mount) | S | B |
| N4 | NOTIF-HINTS | Hud/SmallNotification.luau (HINTS table) | H | B |
| O1 | ONBOARD-NICK | server/Modules/DataService/PlayerSetup.luau, shared/UI/Components/Dialogs/TextInputPrompt.luau | H | B |
| O4 | ONBOARD-NICK | Dialogs/TextInputPrompt.luau:49 (`print(textRef.current)` confirmed) | H | B |
| O2 | ONBOARD-FIRSTRUN | client/Modules/DailyRewardController.luau | H | B |
| O3 | ONBOARD-FIRSTRUN | client/Modules/AreaController.luau (clock-in toast) | H | B |
| T4 | TICKET-RECIPE-LINK | Hud/RecipeCard.luau (reads shared/Configuration/CustomerConfig.luau FAST_FRACTION=0.5) | H | B |
| T8 | TICKET-RECIPE-LINK | Hud/OrderTicket.luau or RecipeCard.luau, shared/UI/Pages/Recipes/init.luau | H | B |
| T7 | none (see below) | OrderTicket FOOTER_DONE already exists | - | - |
| Q3 | QUESTS-PING | server/Modules/QuestService.luau (AdvanceQuest) | H | B |
| Q4 | QUESTS-PING | Hud/BottomRight.luau | H | B |
| H2 | SHIFT-STARS-SOUND | Hud/ShiftCard.luau; sound asset | H | A |
| X1 | RUSH-BANNER (*) | server/Modules/CafeRatingService.luau (RushHour attr exists, add RushEndsAt), Hud/CafeRating.luau | S | B |
| X7 | RUSH-BANNER | Hud/CafeRating.luau banner text; reads server/Scripts/ProcessReceipt.server.luau, shared/Configuration/RatingConfig.luau | S | A |
| S6 | NPC-REACTIONS | server/Modules/CustomerService/Npc.luau (`Npc.Leave` l.436; Wave track exists, ANIMATION_NAMES) | S | B |
| C2 | NPC-REACTIONS | Npc.luau (`Npc._waitOutPatience` l.640; Confused track exists) | S | B |
| S7 | NPC-REACTIONS (*) | shared/Configuration/CustomerDialogue.luau, Npc.luau (`Npc._say` l.561) | S | B |
| S10 | SERVE-FEEDBACK | server/Modules/CustomerService/init.luau (after payout, `_onServeTriggered` l.731) | S | B |
| X3 | SERVE-FEEDBACK | CustomerService/init.luau (toast text ~l.830) | S | B |
| X4 | SERVE-FEEDBACK | CustomerService/init.luau (`RecordTeamServe` l.419) | S | B |
| S8 | SERVE-FEEDBACK | CustomerService/init.luau (deferred, after payout) | S | B |
| S3 | SERVE-PAYPOPUP | CustomerService/init.luau (`_showServePay` l.866), NEW client/Modules/ServeJuice.luau | S | B |
| S9 | SERVE-PAYPOPUP | ServeJuice.luau; particle read from server `SpillService.Storage.Sparkles` (SpillService/init.luau l.75, Spill.luau l.142) | S | A |
| C6 | PATIENCE-RAMP | server/Modules/CustomerService/Rules.luau (`Rules.PatienceSeconds` l.70), CustomerConfig.luau, CustomerService/init.luau (call sites l.367, l.663), Tests/CustomerService.spec.luau | S | B |
| C1 | CLIENT-PATIENCE | client/Modules/KitchenController.luau (updateServePrompts) | S | B |
| C3 | CLIENT-PATIENCE | KitchenController.luau | S | B |
| T5 | CLIENT-PATIENCE | KitchenController.luau (updateServePrompts) | S | B |
| H5 | REALORDER-SHIFT | server/Modules/RealOrderService.luau (payout ~l.292), reads ShiftService:RecordCustomer l.247 | S | B |
| X5 | REALORDER-HEARTS | RealOrderService.luau (`_askHearts` l.167) | S | B |
| X6 | REALORDER-HEARTS (*) | RealOrderService.luau `_askHearts` button labels; Dialogs/ButtonPrompt.luau read | S | B |
| H3 | SHIFT-END | server/Modules/ShiftService.luau, shared/Configuration/ProfileTemplate.luau (add fields only) | S | B |
| H4 | SHIFT-END | Hud/ShiftCard.luau | S | B |
| S2,T3,X2,P6,N5 | SOUNDS | client/Modules/OrderController.luau, Hud/OrderTicket.luau, Hud/CafeRating.luau, Hud/LevelBar.luau, Hud/SmallNotification.luau (SoundEnabled l.139), client/Modules/AppDialogs.luau (`playUiSound`) | S | B |
| Q5 | STREAK-REMINDER | NEW server/Modules/ExperienceNotificationService.luau (no existing file), ProfileTemplate.luau (opt-in flag), reads DailyRewardService.luau | S | A |
| H6 | ENGAGE-SHIFT-STREAK | ShiftService.luau, config (new constants in shared/Configuration) | O | A |
| Q6 | ENGAGE-QUEST-CHAINS | shared/Configuration/QuestConfig.luau, QuestService.luau, Hud/QuestCard.luau | O | A |
| X10 | ENGAGE-FRIEND-INVITE | NEW server/Modules/SocialInviteService.luau (SocialService:PromptGameInvite, client trigger), ProfileTemplate.luau | O | A |
| B1 | BIG-B1 (+ phase packets) | shared/Configuration/Progression.luau (MIN_LEVEL_BY_ITEM l.19), CustomerConfig.luau (ORDER_POOL, LAUNCH_ITEMS), CustomerService/Rules.luau (PickOrder), ProgressionService.luau, Pages/Recipes/{init,Content}.luau | O | B |
| B4 | BIG-B4 | Npc.luau, CustomerService/init.luau, NEW SeatService; asset workspace.Assets.NPC.Seats | O | A |
| B5 | BIG-B5 | NEW RegularsService, ProfileTemplate.luau, Npc.luau, CustomerService/init.luau, RealOrderService.luau (greeting), NEW Pages/Regulars | O | A |
| B6 | BIG-B6 | NEW BoobaPass service/page, ProfileTemplate.luau, ProgressionService.luau (XP stream), catalog (new entries only) | O | A |
| B2 | BIG-B2 | NEW CafeUpgradeService, ProfileTemplate.luau (if per-player), CurrencyService.luau (sink) | O | A |
| B7 | BIG-B7 | server/Modules/KitchenService/* (InteractionRunner.luau), client/Modules/KitchenController.luau | O | A |

Gate note: SOUNDS ships B because the code skips silently when sounds are absent; the sound assets themselves come from Jack/Rigger.

IDs with no packet:
- T7: covered by T1 (GAMEPLAY-MOBILE-TICKET). No packet; Prime appends one Studio-check bullet to GAMEPLAY-MOBILE-TICKET: "Hold a tool matching the ticket on phone: footer turns green 'Ready! Serve your customer' (FOOTER_DONE)". Amend only, no new file.
- None else. Every other approved ID maps. S8's Success sound has no separate packet; it reuses the SOUNDS hook (see (e)).
- Unmapped IDs: none. Excerpt files exist for all 51 NEW IDs. Not verifiable by Grep because they are new files by design: ExperienceNotificationService (Q5), SocialInviteService (X10), ServeJuice, LevelBar, SeatService, RegularsService.

## (b) Packet grouping and agent assignment

Haiku (7 packets, <=4 per agent, read scope <=6 files each): 
- Agent H-A: HUD-BOTTOMLEFT (S4,S5,O5,M4), NOTIF-HINTS (N4), ONBOARD-NICK (O1,O4), ONBOARD-FIRSTRUN (O2,O3)
- Agent H-B: TICKET-RECIPE-LINK (T4,T8), QUESTS-PING (Q3,Q4), SHIFT-STARS-SOUND (H2)
- Routing exceptions: X1, X6, S7 are Haiku-routed but merged into Sonnet packets (RUSH-BANNER, REALORDER-HEARTS, NPC-REACTIONS) because they share files/functions with Sonnet ideas. QUESTS-PING edits AdvanceQuest (can yield): packet must keep new code non-yielding and after existing `SetValue`/`QuestsUpdated`.

Sonnet (<=2 packets per agent):
- Agent S-A: SERVE-FEEDBACK (S10,X3,X4,S8), SERVE-PAYPOPUP (S3,S9)  [same file chain; sequential]
- Agent S-B: NPC-REACTIONS (C2,S6,S7), PATIENCE-RAMP (C6)
- Agent S-C: CLIENT-PATIENCE (C1,C3,T5), HUD-LEVELBAR (P4)
- Agent S-D: REALORDER-SHIFT (H5), REALORDER-HEARTS (X5,X6)  [money path; Sentry review after]
- Agent S-E: SHIFT-END (H3,H4), RUSH-BANNER (X1,X7)
- Agent S-F: SOUNDS (S2,T3,X2,P6,N5), STREAK-REMINDER (Q5)
- Serve-path packets (SERVE-FEEDBACK, SERVE-PAYPOPUP, NPC-REACTIONS S6, PATIENCE-RAMP, REALORDER-*) must state the no-yield rule in invariants.

Opus (one each): BIG-B1, BIG-B2, BIG-B4, BIG-B5, BIG-B6, BIG-B7 (design doc <=400 lines + phase packets <=200 each). One agent: ENGAGE-SHIFT-STREAK (H6), ENGAGE-QUEST-CHAINS (Q6), ENGAGE-FRIEND-INVITE (X10).
- B1 phase 1 (items up to L8, ORDER_POOL/MIN_LEVEL data, Recipe Book locked state) is release-gate B; mastery phase 2 is A. B1 Recipe Book "locked" look is a new visual: Opus builds it from existing tokens only (DEC-053).
- Statuses: B5, B6, B2 = READY-PENDING-CONFIRM (Jack confirms roster, track rewards, upgrade list). B4 = BLOCKED-ON-ASSET until Jack confirms the seat folder. B6 premium track Robux products = HARD STOP 4 (free track and structure only; premium left as inert data with no product IDs).

Total: 28 packets (7 Haiku, 12 Sonnet, 9 Opus counting the ENGAGE trio), plus B-phase packets.

## (c) LEASE MAP (file -> packets in write order; each arrow is a depends_on edge)

Existing packets (dir `packets/`, no YAML frontmatter; scopes read from "Write scope"): 
- GAMEPLAY-TOASTS: SmallNotification.luau, docs/STYLE.md (4.4, 9.8)
- GAMEPLAY-MOBILE-TICKET: Hud/OrderTicket.luau (+story); Part B evidence dir only
- GAMEPLAY-PROGRESS-CALLOUTS: server/Modules/ProgressionService.luau, Hud/ShiftCard.luau (buildLines), client/Modules/AreaController.luau, docs/SYSTEMS.md (one row)
- GAMEPLAY-QUEST-NUDGES: server/Modules/QuestService.luau (AdvanceQuest), Hud/QuestCard.luau (handleClaim)
- GAMEPLAY-SERVE-QUEST-YIELD: CustomerService/init.luau (the CustomersServed AdvanceQuest call only)

| File | Order of writers |
|---|---|
| Hud/SmallNotification.luau | GAMEPLAY-TOASTS -> NOTIF-HINTS -> SOUNDS |
| docs/STYLE.md | GAMEPLAY-TOASTS only (later packets note doc needs for the final consistency pass; they do not edit it) |
| docs/SYSTEMS.md, ARCHITECTURE.md | GAMEPLAY-PROGRESS-CALLOUTS (one row), then the final consistency pass only |
| Hud/OrderTicket.luau | GAMEPLAY-MOBILE-TICKET -> TICKET-RECIPE-LINK -> SOUNDS |
| Hud/RecipeCard.luau | TICKET-RECIPE-LINK |
| Pages/Recipes/init.luau, Content.luau | TICKET-RECIPE-LINK -> BIG-B1 |
| ProgressionService.luau | GAMEPLAY-PROGRESS-CALLOUTS -> BIG-B1 -> BIG-B6 |
| Hud/ShiftCard.luau | GAMEPLAY-PROGRESS-CALLOUTS -> SHIFT-END -> SHIFT-STARS-SOUND |
| client/Modules/AreaController.luau | GAMEPLAY-PROGRESS-CALLOUTS -> ONBOARD-FIRSTRUN |
| QuestService.luau | GAMEPLAY-QUEST-NUDGES -> QUESTS-PING -> ENGAGE-QUEST-CHAINS |
| Hud/QuestCard.luau | GAMEPLAY-QUEST-NUDGES -> ENGAGE-QUEST-CHAINS |
| Hud/BottomRight.luau | QUESTS-PING |
| QuestConfig.luau | ENGAGE-QUEST-CHAINS |
| Hud/BottomLeft.luau | HUD-BOTTOMLEFT -> HUD-LEVELBAR |
| Hud/init.luau, Hud/LevelBar.luau (new) | HUD-LEVELBAR -> SOUNDS (LevelBar flash/sound) |
| CustomerService/init.luau | GAMEPLAY-SERVE-QUEST-YIELD -> SERVE-FEEDBACK -> SERVE-PAYPOPUP -> PATIENCE-RAMP -> BIG-B4 -> BIG-B5 |
| CustomerService/Npc.luau | NPC-REACTIONS -> BIG-B4 -> BIG-B5 |
| CustomerDialogue.luau | NPC-REACTIONS |
| CustomerService/Rules.luau, CustomerConfig.luau | SERVE-FEEDBACK (constants only, optional) -> PATIENCE-RAMP -> BIG-B1 -> BIG-B4 |
| Tests/CustomerService.spec.luau | PATIENCE-RAMP -> BIG-B1 |
| RealOrderService.luau | REALORDER-SHIFT -> REALORDER-HEARTS -> BIG-B5 |
| client/Modules/KitchenController.luau | CLIENT-PATIENCE -> BIG-B7 |
| client/Modules/OrderController.luau, AppDialogs.luau | SOUNDS only |
| CafeRating.luau, CafeRatingService.luau, RatingConfig.luau | RUSH-BANNER -> SOUNDS (CafeRating.luau only) |
| ShiftService.luau | SHIFT-END -> ENGAGE-SHIFT-STREAK |
| ProfileTemplate.luau | SHIFT-END -> STREAK-REMINDER -> BIG-B6 -> BIG-B5 -> BIG-B2 -> ENGAGE-FRIEND-INVITE |
| PlayerSetup.luau, TextInputPrompt.luau | ONBOARD-NICK |
| DailyRewardController.luau | ONBOARD-FIRSTRUN |
| KitchenService/* | BIG-B7 |
| Progression.luau | BIG-B1 |
| CurrencyService.luau | BIG-B2 |
| New files (ServeJuice, LevelBar, ExperienceNotificationService, SocialInviteService, SeatService, RegularsService, Pass/Upgrade/Regulars services and pages) | one writer each, no conflict |

Lease conflicts found (all resolved by depends_on above):
1. CustomerService/init.luau has a 6-deep chain (bottleneck for Wave0 and Wave1/2). Mitigation: later packets anchor by symbol, never line numbers.
2. BIG-B5 and BIG-B6 both write ProfileTemplate.luau in Wave2: serialized B6 -> B5 (B5 also depends_on B4).
3. SOUNDS touches 6 files owned earlier by 5 packets: it runs last in Wave0 and depends_on GAMEPLAY-TOASTS, NOTIF-HINTS, GAMEPLAY-MOBILE-TICKET, TICKET-RECIPE-LINK, RUSH-BANNER, HUD-LEVELBAR.
4. ShiftCard.luau has three writers plus H2; SHIFT-STARS-SOUND must follow SHIFT-END.
5. S10 text collides with TOASTS only if it needs a larger toast; decided as text-only through the TOASTS queue, so no SmallNotification write.
6. C1 could live in OrderTicket (MOBILE-TICKET territory); assigned to KitchenController to avoid a conflict.
7. O1 "after first shift" may need a ShiftService hook not in its Files column; packet must use an existing client signal or report BLOCKED rather than widen scope.

Existing packets needing amendment:
- GAMEPLAY-MOBILE-TICKET: append T7 Studio-check bullet (text only).
- GAMEPLAY-TOASTS: its constraint "No sound is added (SoundEnabled stays unused)" stays true for that packet; SOUNDS (N5) lifts it later. No edit needed; add a depends-on note in SOUNDS.
- GAMEPLAY-SERVE-QUEST-YIELD: mark its "RealOrderService in flight" note as done (M4-FIX-REALORDER-QUEST landed in 49eec97 line); optional.
- The other two need none.
- All five lack YAML frontmatter; Prime may add a minimal `depends_on`/`write_scope` header for the dispatcher without changing bodies.

## (d) Waves

- Wave0 (Haiku + Sonnet packets; order inside the wave by depends_on): 
  1. no deps: HUD-BOTTOMLEFT, ONBOARD-NICK, NPC-REACTIONS, CLIENT-PATIENCE, REALORDER-SHIFT, RUSH-BANNER
  2. after existing five GAMEPLAY packets (assumed landed): NOTIF-HINTS, TICKET-RECIPE-LINK, QUESTS-PING, ONBOARD-FIRSTRUN, SERVE-FEEDBACK, SHIFT-END
  3. then: HUD-LEVELBAR, SERVE-PAYPOPUP, REALORDER-HEARTS, STREAK-REMINDER, SHIFT-STARS-SOUND
  4. then: PATIENCE-RAMP, SOUNDS
- Wave1: BIG-B1 + BIG-B4 (B1: Rules/CustomerConfig/Progression/Recipes; B4: Npc/CustomerService/SeatService; the only shared file is CustomerConfig.luau, so B4 depends_on B1 for that file, or B4 reads it only).
- Wave2: BIG-B6 (depends_on HUD-LEVELBAR P4, ProgressionService) + BIG-B5 (depends_on B4, and B6 for ProfileTemplate).
- Wave3: BIG-B2 + BIG-B7 (B7 depends_on B1; B2 after B5/B6 for ProfileTemplate). Then ENGAGE-SHIFT-STREAK, ENGAGE-QUEST-CHAINS, ENGAGE-FRIEND-INVITE (one Opus agent; after SHIFT-END, QUESTS-PING). Then the consistency pass (Quill: SYSTEMS.md, ARCHITECTURE.md, STYLE.md, ECONOMY-LEDGER.md, ASSET-REQUESTS.md).
- Required orderings satisfied: P4 (HUD-LEVELBAR) before B6; B1 before B7; B4 before B5.

## (e) Asset needs per packet (for ASSET-REQUESTS)

Sound names are under `SoundService.SFX.UI.*` (fallback `SoundService.UISounds.*`); code skips silently when missing.
- SOUNDS: S2 -> `SFX.UI.Serve`; T3 -> `SFX.UI.StepDone`; X2 -> `SFX.UI.Rush`; P6 -> `SFX.UI.LevelUp` (excerpt names `SFX.UI.Success`; request both, code tries LevelUp then Success); N5 -> existing `SFX.UI.Pop1` (verify exists); S2 combo pitch uses `SFX.UI.Serve` PlaybackSpeed only.
- SERVE-FEEDBACK: S10 milestone cue `SFX.UI.Combo` (optional); S8 `SFX.UI.Success` (optional, via SOUNDS hook). Both are client-side, skip silently.
- SHIFT-STARS-SOUND (H2): star jingle, 1-3 rising notes: new sound(s) or pitch-stepped reuse of `SFX.UI.Success`; status READY, code is inert until the sound exists.
- SERVE-PAYPOPUP: S9 particle burst reuses `Storage.Sparkles` from SpillService (server storage) / CleanlinessStorage.Sparkles; no new particle. S3 uses the existing ServePay gui under workspace.Customers.
- NPC-REACTIONS: S6 `Wave` and C2 `Confused` animation tracks (present in Npc.ANIMATION_NAMES; verify the AnimationIds are valid).
- REALORDER-HEARTS: X6 heart icon for rating buttons: verify an existing heart image in `shared/UI` icon set; if none, BLOCKED (no substitute).
- HUD-LEVELBAR / HUD-BOTTOMLEFT / TICKET / QUESTS / RUSH-BANNER / ONBOARD-* / CLIENT-PATIENCE / PATIENCE-RAMP / REALORDER-SHIFT / SHIFT-END / NOTIF-HINTS / STREAK-REMINDER / ENGAGE-*: none (STREAK-REMINDER needs the Roblox ExperienceNotifications feature enabled in the experience settings, a Jack-side setting, not an asset).
- BIG-B1: per new drink the authored giver, recipe chain, syrup dispenser and colour chip in the place file (`Ordering System`, `workspace.Assets`); Recipe Book locked state is built from existing tokens.
- BIG-B4: seat folder `workspace.Assets.NPC.Seats` (HARD STOP 1, BLOCKED-ON-ASSET), sit animations BoothSit/CafeSit/ComfySit/CouchSit (confirm IDs exist), drink prop for the NPC (NPC-LOOK).
- BIG-B5: named regulars' looks/models (Jack authors; status READY-PENDING-CONFIRM).
- BIG-B6: cosmetics for the track (nametags, particles, pet, cup skin) must be existing catalog entries; any new entry needs authored assets; premium track Robux product IDs = HARD STOP 4.
- BIG-B2: authored upgrade models in the place file (Rigger) and plaque; prices PROPOSED.
- BIG-B7: no new assets (meter UI from existing tokens).
- ENGAGE-FRIEND-INVITE (X10): no asset; reward values PROPOSED.
