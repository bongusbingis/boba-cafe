# PACKET-GEN STATUS (2026-10-20, paused on Opus rate limit; resets 5:40pm PT)

Governing: DEC-053 (delegation), DEC-054 (Q-G1..13). Brief: AGENT-BRIEF.md. Rules: WORKER-PRIMER.md. Map: INVENTORY.md.
Source review excerpts: _meta/excerpts/<ID>.md. All packets: source_commit 098175c. Zero src/ edits so far.

## Done (lint clean; HUD-BOTTOMLEFT is 151 lines, accepted)
Wave 0, 19 packets: HUD-BOTTOMLEFT, NOTIF-HINTS, ONBOARD-NICK, ONBOARD-FIRSTRUN, TICKET-RECIPE-LINK, QUESTS-PING, SHIFT-STARS-SOUND, SERVE-FEEDBACK, SERVE-PAYPOPUP, NPC-REACTIONS, PATIENCE-RAMP, CLIENT-PATIENCE, HUD-LEVELBAR, REALORDER-SHIFT, REALORDER-HEARTS, SHIFT-END, RUSH-BANNER, SOUNDS, STREAK-REMINDER (READY-PENDING-CONFIRM).
Partial Wave 1: BIG-B1.md (153), BIG-B1-P1-AUDIT.md (99), BIG-B4.md (176), BIG-B4-P1-PERFCHECK.md (183). Agents died mid-write on the rate limit; re-read these before extending, they may be incomplete.

## Missing
B1: P2-POOL, P3-RECIPEBOOK (UI), P4-MASTERY. B4: P2-SEATS, P3-LEAVE, P4-POLISH (all BLOCKED-ON-ASSET seats).
Not started: BIG-B6, BIG-B5, BIG-B2, BIG-B7, ENGAGE-SHIFT-STREAK/QUEST-CHAINS/FRIEND-INVITE (H6,Q6,X10), CONSISTENCY.md, ASSET-REQUESTS.md, final artifact "Boba Cafe Content Packets Review".
ECONOMY-LEDGER.md has only PATIENCE-RAMP rows.

## Amendments owed (apply in the consistency pass)
- INVENTORY lease: CustomerService/init.luau order = SERVE-QUEST-YIELD > SERVE-FEEDBACK > SERVE-PAYPOPUP > NPC-REACTIONS (adds Leave(reason, grade) call edit) > PATIENCE-RAMP > B4 > B5.
- HUD-LEVELBAR does not edit Hud/init.luau (mounts in BottomLeft CurrencyPanel, LayoutOrder -1). TICKET-RECIPE-LINK writes Hud/init.luau: order it before SOUNDS.
- New spec files: ShiftService.spec (SHIFT-END), CafeRating.spec (RUSH-BANNER). New files: UiSfx.luau (SOUNDS), StreakReminderController.luau, ServeJuice.luau, LevelBar.luau.
- SOUNDS depends_on adds SERVE-FEEDBACK, GAMEPLAY-QUEST-NUDGES, HUD-LEVELBAR (toast texts must not change).
- REALORDER-SHIFT: add `, barista` to RecordTeamServe call (named Team Combo for real orders).
- SERVE-PAYPOPUP: S3 half is release before, S9 half after (split gate). Append T7 Studio-check bullet to GAMEPLAY-MOBILE-TICKET. Add minimal frontmatter to the 5 GAMEPLAY-* packets.
- SHIFT-STARS-SOUND depends_on SHIFT-END (exists now).

## Questions for Jack (batch ONCE, AskUserQuestion)
Q-P1 Sparkles reuse for S9 (CleanlinessStorage.Sparkles)? rec yes. Q-P2 heart image asset id for X6, or keep 1-5? rec keep 1-5 until supplied. Q-P3 wire never-called RealOrderService:_askHearts (new rating prompt, dismissible, 60 s)? rec yes. Q-P4 BOBA_PARTY_PRODUCT_ID value and keep Creator Hub price? (HARD-STOP 4). Q-P5 approve OpenCloudNotifyKey secret + reminder text (STREAK-REMINDER)? rec defer, ships inert. Q-P6 B4 seat folder workspace.Assets.NPC.Seats contract (see BIG-B4.md). Q-P7 B1 items needing place-file confirmation (see BIG-B1-P1-AUDIT.md). Plus CONFIRM lists for B5 roster, B6 rewards, B2 upgrades once drafted.

## Asset requests so far (build ASSET-REQUESTS.md from these)
Sounds under SoundService.SFX.UI: Serve, StepDone, Rush, LevelUp, StarNote (new); Pop1, Success (verify exist). Heart icon (X6). Seats folder + drink prop (B4). Per-drink givers/dispensers (B1). All code skips silently if absent.

## Session 2026-10-20 (resumed, KICKOFF.md)
Phase 1a/1b done: FEEDBACK-VOICE.md, FIRST-5-MIN.md written. Dispatched (running): Sonnet amender (strings -> sheets + owed amendments), Opus B1 P2/P3/P4 stub, Opus UI review. Pending: Jack ship-or-cut confirm (DEC-055), then Phase 2 builders in lease order, stubs for deferred items, short Ship Plan artifact.

## Plan (Opus-first, player-facing/visual first)
See chat 2026-10-20 / KICKOFF.md.

## Session 2026-10-20 part 2
Ship-set builders all committed (see KICKOFF-2.md for hashes). Remaining: B1 build + Espresso/Mango extension, evidence docs commit, Ship Plan artifact, branch review, Studio checklist. Jack decisions: DEC-056 ship set OK, DEC-057 ticket middle-right + Quests button removed, Espresso/Mango yes. Pending from Jack: Hot Cocoa/Strawberry Tapioca place-file checks, sounds.
