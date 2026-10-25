# M1-M4 Batched Playtest Checklist for Jack (DEC-019)

Missing lanes: none
Included lanes: RIG-1, M1.4core, M1.4e, M1.4f, NPC-LOOK, M1.5b, M1.5cd, Q14-GATES, R1-FIX, M2-REALORDER, M2-HEARTS, M2-TICKET2, R2-FIX, M2-SHIFT, M2-PROGRESS, M2-VARIANTS, M2-RATING, SPILLS, SPILLS-CLIENT, TRASH, M2-AREAS, M2-RECIPEBOOK, M1.MEASURE, M3-REM-A, M3-REM-B, M3-REM-C, M3-REM-D, M4-FIXES, M4-FIXES-P3, M4-UI-DAILY-REDO, QUESTCARD-FIX.

Conflicts flagged:
- Quests UI: M4-UI-DAILY-REDO tested a separate Quests menu dialog without a HUD card, while QUESTCARD-FIX tested the HUD QuestCard. Both test sets are copied below (DEC-057 removed the Quests menu button).

---

## Part A: Setup and TestEZ

### 0. Pre-flight Setup
- Rojo synced to Studio.
- Place saved in Studio.

### 1. TestEZ Automated Suite
Jack action:
- In `src/server/Tests/RunTests.server.luau` set `TESTS_ENABLED = true` locally.
- Press Play in Studio, open Output window, and record pass count, fail count, and each failure name.
- Set `TESTS_ENABLED` back to `false` and confirm clean working copy with `git diff`.

Results:
- Passed: ___
- Failed: ___
- Failures: ___

Stale-spec note (from M3-REM-A):
> "The _endShift test fires the Knit client signal unguarded, so it may need a fix if TestEZ shows an error there."
Expect a ShiftService `_endShift` failure; report it, do not treat it as a regression.

Expected specs in suite:
OrderService, OrderSpec, KitchenAttributes, CustomerService, ShiftService (see note above), RealOrder, CafeRating, PerkService, QuestService, DailyRewardService, Progression, TeamCombo, InventoryLimit, BadgeService, TreasureHuntService, LeaderboardService.

---

## Part B: Play Tests Grouped by Lane

### Milestone 1

#### RIG-1: Spawns, Doors, and Startup
1. Boot output check (PC). Expect: No missing warnings from CustomerService, SpillService, SpillController, TrashService, UniformService, AreaController. [ ] pass  [ ] fail
2. Interior spawn location (phone). Expect: Spawn inside kitchen near Clear Cup (SpawnInterior1-4); old outside spawns inactive. [ ] pass  [ ] fail
3. Kitchen barrier collision (phone). Expect: Walk freely through kitchen doors and counter; GroupDoors walls non-collide. [ ] pass  [ ] fail
4. Player pass-through collision (PC). Expect: Two players walk through each other without body-blocking behind counter. [ ] pass  [ ] fail

#### M1.4core / M1.4e / M1.4f / NPC-LOOK: NPC Customers
5. NPC arrival and pathing (phone). Expect: Clock in: NPCs spawn at Entry, follow Path, queue up, step to registers Counter 1-5. [ ] pass  [ ] fail
6. NPC look and overhead bubble (phone). Expect: Wave and greeting on arrival, Idle anim plays, bubble shows order and green-to-red patience bar. [ ] pass  [ ] fail
7. Patience pause when unclocked (phone). Expect: Patience pauses when nobody is clocked in; at zero NPC leaves via Exit without penalty. [ ] pass  [ ] fail
8. Ticket and prompt visibility (PC). Expect: Ticket appears; Serve and Rescue prompt visibility works correctly across 2 clients. [ ] pass  [ ] fail
9. NPC drink serve payout (phone). Expect: Correct serve increases BobaBucks (M1.4e); wrong serve triggers Confused animation and WrongOrder line. [ ] pass  [ ] fail
10. Uniform equip on clock in (phone). Expect: Clock in equips barista uniform; clock out restores player original clothes. [ ] pass  [ ] fail

#### M1.5b / M1.5cd / Q14-GATES: Kitchen Guidance and Recipes
11. Recipe card updates (phone). Expect: Recipe ticks update within 0.2s of station action; shows Wrong/Close; collapses on phone. [ ] pass  [ ] fail
12. Station guidance beam (phone). Expect: Gold Highlight and beam on next station; hides after 4 repeats until 20s idle. [ ] pass  [ ] fail
13. Station hints setting toggle (phone). Expect: Settings > Staff > Station hints off removes highlight, beam, and toasts. [ ] pass  [ ] fail
14. Wrong station guidance (phone). Expect: Wrong station shows "Next: X" toast; picker buttons pulse gold; unclocked shows Clock In toast. [ ] pass  [ ] fail
15. Coffee preparation and ingredients (phone). Expect: Small cup -> Coffee Machine Regular (4s hold) -> Perfect serve; Sugar/Ice order invariant. [ ] pass  [ ] fail

---

### Milestone 2

#### R1-FIX / M2-REALORDER / M2-HEARTS / M2-TICKET2 / R2-FIX: Real Orders and Ratings
16. Off-menu orders filter (phone). Expect: Off-menu smoothie refused; Regular, Brownie, Boba work; only launch items show in menus. [ ] pass  [ ] fail
17. Pickup node claim collision (PC). Expect: Two baristas: occupied pickup node says "This spot is taken"; clock out releases claimed order. [ ] pass  [ ] fail
18. Re-depositing drink guard (phone). Expect: Re-depositing a picked-up drink displays "An item is missing". [ ] pass  [ ] fail
19. Self-serve order prevention (phone). Expect: Solo, clocked in, order drink: not assigned to self; no real-customer pay/XP/quest (R2-FIX). [ ] pass  [ ] fail
20. Two-player real order payout (PC). Expect: Second player serves your order; barista gets normal pay; customer gets nothing extra (R2-FIX). [ ] pass  [ ] fail
21. Real order multi-client scaling (PC). Expect: 3 clients: auto-assigns; x2 pay first 3 orders then x1; customer keeps drink; RegularOrders advances. [ ] pass  [ ] fail
22. Barista rating prompt appearance (PC). Expect: Customer pickup shows "Rate your barista" prompt with buttons 1-5 naming barista; cannot rate self. [ ] pass  [ ] fail
23. Rating score submission (PC). Expect: Tapping 4 adds HeartsReceived +4, HeartsCount +1; dismiss adds nothing; prompt shows once per order. [ ] pass  [ ] fail
24. Pickup ready beam (phone). Expect: Ready beam appears to pickup node when drink ready, clears on pickup (needs place PickupBeam). [ ] pass  [ ] fail
25. Level 5 stacked tickets (phone). Expect: At L5 player holds 2 tickets stacked; overhead displays unlocked title under name. [ ] pass  [ ] fail

#### M2-SHIFT / M2-PROGRESS / M2-VARIANTS / M2-RATING: Progression and Rating
26. Shift completion cards (phone). Expect: Serve 5 shows shift card for 8s ("Next shift starts now"); 10 more shows 6s; Shift k/N while clocked in. [ ] pass  [ ] fail
27. Level up and nametag unlock (phone). Expect: Serve 5 customers: XP and Level attributes increase, level-up toast shows, L5 nametag added to inventory. [ ] pass  [ ] fail
28. Customer variants by level (phone). Expect: L10 profile spawns Karen (Confused on Close, stomps out); L6 VIP gold bubble; L5 two-item orders. [ ] pass  [ ] fail
29. Cafe rating meter and rush (phone). Expect: Rating meter at top centre; Rush toast and pay triggers; meter frozen during Rush; spill XP 5. [ ] pass  [ ] fail

#### SPILLS / SPILLS-CLIENT / TRASH / M2-AREAS: World Maintenance
30. Floor spills and mopping (phone). Expect: Spill appears on floor; mopping gives sparkles and SpillsCleaned +1; walking on it trips player. [ ] pass  [ ] fail
31. Trash can drink disposal (phone). Expect: 6 trash cans: hold drink, Use -> Yes deletes tool; No keeps; NotDisposable refused; >12 studs keeps tool. [ ] pass  [ ] fail
32. Break area gate barrier (phone). Expect: Level 1 blocked by gate with sign; Level 3 gates vanish immediately without rejoin (M2-AREAS). [ ] pass  [ ] fail

#### M2-RECIPEBOOK / M1.MEASURE: Menus and Telemetry
33. Recipe Book content (phone). Expect: Recipe Book lists each ORDER_POOL item; Tips tab is present. [ ] pass  [ ] fail
34. Analytics telemetry events (PC). Expect: Play analytics events fire to dashboard (optional check). [ ] pass  [ ] fail

---

### Milestone 3

#### M3-REM-A: Shift Star Bonus
35. Shift star bonus payouts (phone). Expect: Shift completed with 1/2/3 stars awards 5/10/15 BobaBucks bonus in summary card. [ ] pass  [ ] fail

#### M3-REM-B: Pass and Pet Perks
36. Baseline pay without perks (phone). Expect: Without gamepasses or pets: serve pay and XP match baseline amounts exactly. [ ] pass  [ ] fail
37. Barista pass boost stack (phone). Expect: Own Barista pass: NPC serve pay +25% and XP +25%; own Kitchen Leader too: +50% total, not +75%. [ ] pass  [ ] fail
38. Pet tip bonus highest win (phone). Expect: Equip Legendary pet (no pass): pay +10%; Barista pass plus Legendary pet: +25% (highest bonus wins). [ ] pass  [ ] fail
39. Real order perk bonus (PC). Expect: Real-player order served: same tip boost percentage applies to barista payout. [ ] pass  [ ] fail
40. Core systems perk safety (phone). Expect: Quests, daily rewards, and Instant Brewing continue normal behavior with perks active. [ ] pass  [ ] fail

#### M3-REM-C: Team Combo
41. Team combo activation (phone). Expect: Serve 10 customers in a row without walkout: all players see "Team Combo! +10% pay for 60 seconds!". [ ] pass  [ ] fail
42. Team combo payout multiplier (phone). Expect: During 60s window: serve pay multiplied by 1.10 rounded before tip bonus; real orders boosted too. [ ] pass  [ ] fail
43. Team combo completion (phone). Expect: At 60s all players see "Team Combo is over." and pay returns to normal. [ ] pass  [ ] fail
44. Team combo walkout reset (phone). Expect: Customer walks out mid-chain (e.g. after 6 serves): chain resets to 0, requiring 10 new serves. [ ] pass  [ ] fail
45. Team combo window refresh (phone). Expect: Finish second 10-chain during active combo: refreshes window to full 60s with no early expiration. [ ] pass  [ ] fail
46. Rush Hour and Team Combo stack (phone). Expect: During Rush Hour plus Team Combo: serve pay multiplied by x2 then x1.10. [ ] pass  [ ] fail

#### M3-REM-D: Double Storage Pass
47. Baseline inventory capacity (phone). Expect: Set BASE_STORAGE=3: without pass, buying nametag capsule at 3 refuses (InventoryFull); no BB spent. [ ] pass  [ ] fail
48. Double storage pass capacity (phone). Expect: With Double Storage pass (14067346): capsule purchases succeed up to 6 before refusing. [ ] pass  [ ] fail
49. Reward grant storage limits (phone). Expect: At 3 items without pass: daily or chest capsule refuses; with pass at 4 items succeeds. [ ] pass  [ ] fail
50. Equipped inventory limits (phone). Expect: Equipped limits unchanged: 1 pet, 1 nametag, 5 particles max. [ ] pass  [ ] fail
51. Over-limit item retention (phone). Expect: Over-limit (pass lost): items not deleted, usable and sellable; new additions refused until under limit. [ ] pass  [ ] fail
52. Rapid join inventory claim (phone). Expect: Claim capsule in first second after join: refused or granted, never over-granted; retry works. [ ] pass  [ ] fail
53. Mid-session pass activation (phone). Expect: Double Storage pass bought mid-session takes effect after rejoining. [ ] pass  [ ] fail

---

### Milestone 4

#### M4-FIXES: Economy, Badges, and Leaderboards
*Note: Statue 2 may still have a "Most Tips" sign that needs a Studio relabel.*
54. Treasure chest cooldown (phone). Expect: Open treasure chest, then another within 15 min: second refused with "Next treasure chest in N min". [ ] pass  [ ] fail
55. Treasure chest reward amounts (phone). Expect: Chest grants 20-40 BobaBucks; pet capsule awarded roughly 1 in 10 chests. [ ] pass  [ ] fail
56. Veteran badge qualification (phone). Expect: Profile with only FirstStaff badge gets no Veteran title; FirstQuest or other legacy badge grants Veteran. [ ] pass  [ ] fail
57. Active leaderboard display (PC). Expect: After 2 min: Orders Served, Boba Bucks, Most Active fill; Most Tips and Top Donators boards dark. [ ] pass  [ ] fail
58. Leaderboard statue 2 display (PC). Expect: Statue 2 displays Most Boba Bucks leader (relabel sign if reading Most Tips). [ ] pass  [ ] fail
59. Daily claim full inventory (phone). Expect: Full capsule inventory on Day 4/7: toasts "inventory is full", claim remains available, streak unchanged. [ ] pass  [ ] fail
60. Daily reward schedule amounts (phone). Expect: Daily rewards show BB amounts 30/45/60/60/90/120/180 across Days 1-7. [ ] pass  [ ] fail
61. Quest reroll price and rewards (phone). Expect: Quest HUD reroll button displays "20 BB"; quest rewards scale with target difficulty. [ ] pass  [ ] fail

#### M4-FIXES-P3: Exploits and Leaderboard Hardening
62. Promo code BB exclusion (phone). Expect: Redeem BB promo code: wallet increases but MostBobaBucks leaderboard does not rise; Points code works. [ ] pass  [ ] fail
63. Item sell BB exclusion (phone). Expect: Sell pet/nametag: wallet increases, MostBobaBucks unchanged; NPC serve and chest do increase MostBobaBucks. [ ] pass  [ ] fail
64. Chest interact spam throttle (phone). Expect: Hold E on chest repeatedly for 10s: at most 2 cooldown toasts appear (one per 5s), no chest opens. [ ] pass  [ ] fail
65. Leaderboard retry on failure (PC). Expect: Studio with DataStore off: warning "Failed to update stat", 3 retries on interval, then "Dropping". [ ] pass  [ ] fail
66. Barista disconnect safety (PC). Expect: Two players: real order made, barista leaves immediately after drink pickup: no errors in Output. [ ] pass  [ ] fail
67. Real order combo anti-boost (PC). Expect: Barista serves same real customer 4 times in 10m: 4th pays x1 and does not advance Team Combo. [ ] pass  [ ] fail

#### M4-UI-DAILY-REDO: Daily and Quests Dialog UI
68. Daily rewards menu layout (phone). Expect: Claim ready: Daily opens automatically as menu; close with X; no screen dim; styled like Shop. [ ] pass  [ ] fail
69. Daily rewards claim flow (phone). Expect: Claim Day N: toasts amount, button becomes countdown timer, menu does not re-bounce every second. [ ] pass  [ ] fail
70. Quests menu interaction (phone). Expect: Quests button opens menu; pressing again closes; shows progress, Claim, Claimed, 20 BB reroll. [ ] pass  [ ] fail
71. Daily and Quests mobile view (phone). Expect: Emulator landscape and portrait: text fully readable; bottom-left column fits screen. [ ] pass  [ ] fail

#### QUESTCARD-FIX: QuestCard HUD Layout
72. QuestCard HUD layout (phone). Expect: Daily Quests header green with readable text; collapses on click; rows show bar with Reroll/Claim on right. [ ] pass  [ ] fail

#### R2-FIX: Cross-Cutting Edge Cases
73. Quest reroll and claim race (phone). Expect: Rapidly reroll and claim a quest: quest is never both paid and replaced. [ ] pass  [ ] fail
74. Chest with full capsules (phone). Expect: Open chest with full capsule inventory: BB granted, no capsule awarded, no script error. [ ] pass  [ ] fail

---

## Part C: Results Summary

| Lane | Milestone | Steps Passed | Steps Failed | Notes |
|---|---|---|---|---|
| RIG-1 | M1 | | | Steps 1-4 |
| M1.4core / M1.4e / M1.4f / NPC-LOOK | M1 | | | Steps 5-10 |
| M1.5b / M1.5cd / Q14-GATES | M1 | | | Steps 11-15 |
| R1-FIX / M2-REALORDER / M2-HEARTS / M2-TICKET2 / R2-FIX | M2 | | | Steps 16-25 |
| M2-SHIFT / M2-PROGRESS / M2-VARIANTS / M2-RATING | M2 | | | Steps 26-29 |
| SPILLS / SPILLS-CLIENT / TRASH / M2-AREAS | M2 | | | Steps 30-32 |
| M2-RECIPEBOOK / M1.MEASURE | M2 | | | Steps 33-34 |
| M3-REM-A | M3 | | | Step 35 |
| M3-REM-B | M3 | | | Steps 36-40 |
| M3-REM-C | M3 | | | Steps 41-46 |
| M3-REM-D | M3 | | | Steps 47-53 |
| M4-FIXES | M4 | | | Steps 54-61 (Statue 2 note) |
| M4-FIXES-P3 | M4 | | | Steps 62-67 |
| M4-UI-DAILY-REDO | M4 | | | Steps 68-71 |
| QUESTCARD-FIX | M4 | | | Step 72 |
| R2-FIX (cross-cutting) | M2/M4 | | | Steps 73-74 |

Report failures to Prime with the step number.
