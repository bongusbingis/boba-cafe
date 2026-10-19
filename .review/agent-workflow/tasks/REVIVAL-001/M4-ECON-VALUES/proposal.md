RESULT: WAITING (PENDING JACK, DEC-034/DEC-035 Q1=A)

# M4-ECON-VALUES: Prime proposal for daily, chest and quest rewards

Anchor: E2 sets 9 BB/min solo, which is 540 BB/hour. "Min" below means minutes of normal solo play at
that anchor. The anchor is the approved design value, not a measured rate.
Reference prices: Regular capsule 75 BB, Nametag 150, Rare 250, Epic 1200 (E9).

Principle: return loops should feel like a bonus on top of play, never a substitute for it.
- Daily login averages about 10 min/day; Day 7 is the pull.
- Chests stay well under a third of hourly income.
- A quest pays roughly half again the time it takes.

## Daily streak (cooldown 20h and expiry 48h kept; VIP x2 per E20)
| Day | Coded | Proposed |
|---|---|---|
| 1 | 50 | 30 |
| 2 | 75 | 45 |
| 3 | 100 | 60 |
| 4 | 125 + Regular | 60 + Regular |
| 5 | 150 | 90 |
| 6 | 200 | 120 |
| 7 | 300 + Rare | 180 + Rare |
| Week | 1000 BB (VIP 2000) | 585 BB (VIP 1170), about 65 min |

Why lower: the coded week is about 111 min of play, and 222 min with VIP. That's more than many players'
weekly playtime, and it would undercut the shop. The capsules carry Day 4 and Day 7.

## Treasure chests (with the Q2 cooldown of 1 chest per 15 min per player)
- Coded: 35-100 BB, 15% capsule (Regular or Nametag).
- Proposed: 20-40 BB, 10% capsule (same two capsules).
- Effect: at most 4 chests/hour, about 120 BB + 0.4 capsule, about 20% of hourly income. The coded values
  give up to 270 BB/hour, half the anchor, for walking around.

## Daily quests (reward scales with the rolled target instead of a flat amount)
| Quest | Targets | Coded BB/XP (flat) | Proposed BB by target | Proposed XP |
|---|---|---|---|---|
| Prepare Boba | 3/5/8 | 50/25 | 25/40/60 | 15/25/35 |
| Serve Customers | 5/10/15 | 60/30 | 25/40/60 | 15/25/35 |
| Clean Spills | 2/4/6 | 40/20 | 20/30/45 | 10/20/30 |
| Serve Real Players | 1/2 | 75/40 | 40/75 | 25/40 |
| Complete Shifts | 1/2 | 50/25 | 40/75 | 25/40 |

A day's 3 quests pay about 135 BB (15 min). Tiering needs a small QuestConfig change: one reward per
target index.

## Open point for Jack
The quest reroll costs 50 BB (approved structure), but a typical quest under this proposal pays 25-60 BB,
so paying to reroll is rarely worth it. Options: keep 50, or lower it to 20.
