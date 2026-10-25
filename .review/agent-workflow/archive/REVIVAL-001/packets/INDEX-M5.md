# Milestone 4 UI & Milestone 5 Pre-Release Hardening Index

Governed by: `tasks/REVIVAL-001/kickoff-next-session.md`, `revival-plan.md` (§4.7, §8 M5), `decisions.md` (DEC-013, DEC-032).

## Packet Roster

| ID | Title | Scope | Role | Status |
|---|---|---|---|---|
| M4-UI-DAILY-REWARD | 7-Day Daily Login Rewards Modal Dialog | `DailyRewardsDialog`, `DailyRewardController`, `BottomLeft` | Lens / Mason | Ready |
| M4-UI-QUESTS | Daily Quests HUD Card & Interaction | `QuestCard`, `Hud/init` | Lens / Mason | Ready |
| M5-SENTRY-REMOTES | Sentry Exploit & Authority Security Review | Knit Remotes across all services, `R2-SECURITY` | Sentry | Ready |
| M5-LEGACY-AUDIT | Legacy Workspace Scripts Safety Audit | `Workspace.OldScriptables` & `Map` scripts, `LEGACY-AUDIT` | Scout / Sentry | Ready |

## Execution Waves
- **Wave 1 (Parallel)**:
  - `M4-UI-DAILY-REWARD`: builds the FredokaOne 7-day modal dialog, client controller, and HUD button.
  - `M4-UI-QUESTS`: builds the reactive daily quest card with progress bars, claim, and reroll buttons.
  - `M5-SENTRY-REMOTES`: security audit and input hardening on all backend Knit remotes.
  - `M5-LEGACY-AUDIT`: Studio MCP read-only inspection of remaining legacy scripts.
