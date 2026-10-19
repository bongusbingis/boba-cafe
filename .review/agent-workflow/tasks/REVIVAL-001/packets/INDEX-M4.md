# Milestone 4: Retention & Return Loops Packet Index

Governed by: `tasks/REVIVAL-001/revival-plan.md` (§4.7, §8 M4) and `decisions.md` (DEC-032).

## Packet Roster

| ID | Title | Scope | Model | Status |
|---|---|---|---|---|
| M4-DAILY-STREAK | 7-Day Login Streak & Daily Rewards | `DailyRewardConfig`, `DailyRewardService`, `DailyRewardService.spec` | sonnet / spark | PASS |
| M4-QUESTS | Daily Quests & Core Loop Hooks | `QuestConfig`, `QuestService`, `QuestService.spec`, hooks | sonnet / spark | PASS |
| M4-TREASURE-CHESTS | Hidden Treasure Chests & Spawning | `TreasureHuntConfig`, `TreasureHuntService`, `TreasureHuntService.spec` | sonnet / spark | PASS |
| M4-LEADERBOARDS | Monthly Leaderboards & Statues | `LeaderboardConfig`, `LeaderboardService`, `LeaderboardService.spec` | sonnet / spark | PASS |
| M4-EVENTS | Server Events (Rush Hour, Karen Day, Treasure Frenzy) | `EventConfig`, `EventService`, `EventService.spec`, hooks | sonnet / spark | PASS |
| M4-VETERAN | Legacy Badge Veteran Overhead Title | `BadgeService`, `PlayerOverheads`, `BadgeService.spec` | haiku / spark | PASS |

## All Milestone 4 Deliverables Complete
All 6 tasks have been built, hooked into the core game loop, verified with unit specs, passed WSL static gates (0 Selene findings, StyLua formatted, Rojo build passed), and recorded in `completed.ndjson`.
