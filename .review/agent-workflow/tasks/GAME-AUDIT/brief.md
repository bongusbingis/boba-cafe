# GAME-AUDIT — whole-game gaps, 2026-10-22 (Jack request)

Method: 5 parallel read-only domain audits + critic + gap follow-up + synthesis
(workflow boba-gap-audit), then firsthand verification of every load-bearing
claim repeated below. Status: partial — 45-spec cross-check sampled 6/45, no
TestEZ observed in review (suite run is Jack's per convention).

## Fixed during audit (verify in your TestEZ run)
- Watermelon/Dragon Fruit were in LAUNCH_CHOICES + ORDER_POOL but NOT in Menu
  SyrupFlavor -> NPCs would order unmakable drinks. Added both with colors to
  [Menu.luau](/C:/Users/jackc/Desktop/boba-cafe/src/shared/Ordering/Menu.luau);
  all 19 syrups + 10 tapiocas now confirmed at table level. Gate PASS.

## Bugs needing Jack's call
1. Dead quest advances MacaronOrdered/HotChocolateOrdered
   ([OrderService.luau](/C:/Users/jackc/Desktop/boba-cafe/src/server/Modules/OrderService.luau) 795-798;
   no templates in QuestConfig 35-74; silent no-ops): remove calls or add templates.
2. ProfileTemplate Statistics TYPE lacks CustomersServed (defaults line 164
   has it): [ProfileTemplate.luau](/C:/Users/jackc/Desktop/boba-cafe/src/shared/Configuration/ProfileTemplate.luau) 25-40.
3. ShiftTimerEnabled Settings toggle has no UI effect:
   [BottomLeft.luau](/C:/Users/jackc/Desktop/boba-cafe/src/shared/UI/Components/Core/Hud/BottomLeft.luau) + SettingsConfig 101.
4. "Boba Cafe" place drifts from code ("Boba Cups" vs Clear Cup, "Fridge" vs
   Ice Cream Freezer, "Coffee Sugar" vs Sugar, etc.). Dev place matches.
   Confirm dev place is canonical before any publish from the other.

## Content/design decisions
5. 8 Menu syrups with no stations (Banana/Avocado/Honeycomb/Almond/Mint/
   Orange/Blueberry/Peach): prune or approve stations.
6. Latte branch, Oolong powder, Salted cocoa powder: confirm off-launch or approve.
7. Commented Pumpkin Spice Boba block: ship or delete.
8. Zero-pool level gates (Hot Cocoa 3, Macarons 4, Cappuccino 7, Mochis 8,
   Americano 12, Ice Creams 12): confirm NPCs never ordering them is intended.
9. PAY_TABLE/PATIENCE_BONUS fallbacks for grab categories: confirm intended.
10. Open Q3/Q22/Q25 (boba sizes, tea/water chains, NPC look) + 60 Regulars
    catalog outfit ids: [RegularsConfig.luau](/C:/Users/jackc/Desktop/boba-cafe/src/shared/Configuration/RegularsConfig.luau) 58-62.
11. Tuning: newcomer weights + CLASSIC_MIN_SHARE (provisionals are weight 1);
    Progression/weekly/seating/leaderboard PROPOSED/PENDING numbers; Points
    has no sink (SHOW_POINTS false); StationHold50 + Instant Brewing perks
    unread; CapsuleRobux IDs nil (no Robux capsule offer).
12. BottomRight.luau unmounted but SYSTEMS documents Quests button as live:
    delete file or update docs (DEC-057).
13. DEC-019: 0 entries in decisions.md, cited in board.json + 79 files.
    Needs a superseding entry on Play/TestEZ ownership (governs agents too).

## Docs (say the word and I'll fix)
- SYSTEMS: missing Regulars/BobaPhone/PassSettings/EventFx sections; stale
  register-prompt section; false MinRank claim; wrong SFX group name.
- ARCHITECTURE: omits RegularsService/BobaPhoneService/PassSettingsService/
  BobaPhoneController/EventFxController/Pages/BobaPhone.
- STYLE: ticket spec stale; BobaPhone legacy theme uncatalogued (DEC-043).

## Verified healthy (no action)
NPC/regular/variant loop, quest completability, rating deltas, events with
content, BobaPhone/counter mutual exclusion, receipt granting paths,
TESTS_ENABLED off + guarded, project-file mappings, all pool keys resolve to
Progression levels, classic-share law holds (worst 0.649 at L15+).
