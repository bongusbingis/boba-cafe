# Current State Constitution

Active, authoritative rules governing the codebase distilled from the decisions ledger. All superseded historical rules have been omitted.

## 1. Architecture & Patterns

- **Target Place & Fresh Start:** The game ships directly over place `718328620` as a complete fresh start with no legacy currencies, profiles, or player inventory data carried over.
- **Map & Spatial Anchoring:** Retain the existing map and legacy `workspace.OldScriptables` models; move or clone instances rather than deleting them, and anchor counter and NPC routes to `workspace["Ordering System"]`.
- **No Group-Rank Gating:** Group ranks are restricted to overhead titles, chat tags, staff moderation, and server event hosting; gameplay features and stations are never gated behind group rank.
- **Player-to-Player Collisions:** Collisions between players are disabled inside the cafe via `CustomerService` collision groups to prevent station and register griefing.
- **Server Authority & Logic Isolation:** Currency, inventory mutations, receipts, and order states are strictly server-authoritative; business logic belongs in requireable ModuleScripts to maintain testability outside `.server` scripts.
- **Receipt Validation & Compensation:** Developer product receipts (such as Skip Hatch) received without an active prerequisite state are treated as invalid (`NotProcessedYet`) and grant no credit. BobaBucks compensation uses a single additive `PendingBobaBucksRefund` profile attribute reconciled on join without complex transaction ledgers.
- **Spill & Cleanliness Architecture:** Cleanliness assets and animations are imported from legacy storage (`ReplicatedStorage.SharedStorage.CleanlinessStorage`); the in-world cleanliness SurfaceGui is retired in favor of HUD-only rating indicators.
- **Station & Disposal Mechanics:** Drink preparation utilizes existing kitchen machine water spouts without physical sink models; six cafe trash cans prompt players to discard held tools unless flagged `NotDisposable`.
- **Leaderboards & Statues:** Active monthly leaderboards track Most Orders Served, Most Boba Bucks, and Most Active (Most Tips and Top Donators are hidden); Statue 2 displays the #1 Most Boba Bucks player, and currency from promo codes or item sales is excluded from board tracking.
- **Titles & Badges:** The Veteran overhead title is granted exclusively to owners of retired legacy badges (`FirstQuest`, `Celebrity`, `SakuraIsland`, `ShinyPet`, `HalloweenEvent`); level progression titles display on character overheads beneath display names.

## 2. Gameplay & FTUE

- **Automated Order Dispatch:** The manual claim queue and HUD order queue are removed; orders automatically route to the longest-idle clocked-in barista with an open ticket slot.
- **Counter Ordering Flow:** Unseated, clocked-out players at empty counter registers trigger a server-locked "Take Order" prompt for baristas, placing the customer's order onto a standard ticket slot tagged "Real customer".
- **NPC Counter Flow:** Waiting counter NPCs present a clickable "Take Order" billboard bubble visible only to clocked-in baristas (with gamepad interaction as fallback).
- **Tablet Order Entry:** Taking an NPC order always copies the order text into the barista tablet notepad; automatic one-tap prefill is permanently removed across all sessions.
- **Ticket Stacking & Concurrency:** Baristas hold up to two active order tickets simultaneously; tickets stack upward from the middle-right of the screen and treat NPC and player orders uniformly.
- **Drink Progression Gating:** Recipe availability requires verified end-to-end station chains; early unlocks follow Taro and Strawberry syrups (L2), Hot Cocoa Classic (L3), and Strawberry tapioca (L4).
- **Onboarding & First-Session Flow (FTUE):** New players receive a nickname prompt with a Skip option after their first shift, grant one server-side Regular Pet Capsule on shift completion, and auto-open the Daily Rewards menu after their first successful serve.
- **Cafe Rating Dynamics:** Successful fast serves add +1% rating and spill cleanups add +3% rating (and 5 XP); wrong serves or walkouts deduct −2% rating, and active spills slowly drain rating over time.
- **Team Combo Mechanics:** Ten consecutive successful serves server-wide (NPC or player) trigger a 60-second Team Combo granting +10% BB pay; the combo refreshes upon hitting subsequent 10-chains and resets only upon a customer walkout.
- **NPC Dialogue & Presentation:** NPCs reuse legacy dialogue pools and animations (Wave, Confused, Idle); served customers speak farewell lines upon departure, while walkouts express dissatisfaction.
- **Server Events:** Staff members of rank 10 or higher can initiate scheduled 10-minute server events (Rush Hour, Karen Rush, Treasure Frenzy); Boba Party acts as a 10-minute Rush Hour with a 10-minute cooldown and stacks multiplicatively with active Team Combos.

## 3. Monetization & Economy

- **Earning Anchor & Multipliers:** The core economy balances against a baseline earning rate of ~9 BB/min; tip boosts multiply final BB pay on serves, with only the highest boost in a family applying.
- **Daily Login Streak:** A repeating 7-day cycle awards escalating BobaBucks (30, 45, 60, 60 + Regular Capsule, 90, 120, 180 + Rare Capsule) on a 20-hour cooldown and 48-hour reset window; VIP pass holders receive 2× BB rewards.
- **Daily Quests:** Players receive 3 daily quest slots (plus 1 bonus slot for Star Employee or More Quests pass owners); Star Employee grants 1 free reroll daily, with additional rerolls costing 20 BB.
- **Hidden Treasure Chests:** Three to five shared treasure chests spawn across world nodes on a 90-second respawn; individual players may claim one chest every 15 minutes for 20–40 BB and a 10% capsule chance.
- **Pet Capsule Pricing & Tiers:** Pet capsules cost 75 BB (Regular), 250 BB (Rare), and 1200 BB (Epic); Nametag capsules cost 150 BB individually (or 10 for 1,350 BB / 50 for 6,000 BB).
- **Capsule Odds & Compliance:** Pet hatch odds follow coded tier weights (50% Basic down to 1% Legendary); Robux capsule purchasing is prohibited without PolicyService compliance and visible numeric odds disclosure.
- **Pet Tip Boosts & Inventory Limits:** Equipped pets grant tip multipliers (+2% Basic, +4% Rare, +7% Epic, +10% Legendary); the Double Storage perk doubles inventory storage capacity only and does not expand equipped slots.
- **Robux Price Authoring:** Robux prices must never be hardcoded in client or server scripts; in-game displays query live data via `MarketplaceService:GetProductInfoAsync`.
- **Deferred Economy Mechanics:** BobaBucks-based hatch skips, cafe upgrade sinks, standalone tip jars, 30-minute tip booster products, and direct player-to-player tipping remain deferred.

## 4. UI & Style

- **Strict Replication (STYLE.md):** All interfaces must strictly follow `docs/STYLE.md` using existing tokens, components, and patterns; introducing new colors, fonts, corner radii, or spring curves without approval is prohibited.
- **Order Ticket HUD:** Tickets are scaled at 1.6× and anchored at the middle-right of the screen (`0.99, 0.65`) expanding upward, showing a "Fast bonus!" indicator when customer patience remains above 50%.
- **Quests Interface:** Quests display exclusively in a centered pop-up modal with finger-friendly buttons; always-on HUD cards are prohibited, and the bottom-right HUD button is temporarily removed pending a future menu pass.
- **Daily Rewards Integration:** Daily rewards are embedded as Tab 2 within the primary Menu UI; the standalone daily dialog is reserved strictly for the first-join auto-open flow and renders without a dim backdrop.
- **HUD Metres & Bar Elements:** Cafe Rating is rendered as a compact top-centre meter below the clock, and the player level pill with XP bar rests directly above the ShiftCard.
- **Serve Feedback & Announcements:** Successful serves trigger a floating, rising "+N BB" text popup in gold with derived stroke; team combo alerts route through existing announcement toasts without dedicated screen overlays.
- **Audio & Visual Restraint:** UI buttons are silent upon press; missing audio assets remain silent rather than using unapproved replacements, and level-ups temporarily borrow `SFX.UI.Success`.

## 5. Agent Workflow

- **Governing Architecture & Roles:** Claude Opus serves as Prime; `docs/` and `AGENTS.md` provide the sole operational workflow, superseding legacy role and routing designations.
- **Jack Hard Approvals:** Explicit user confirmation is strictly required for publishing, economy pricing, catalog odds/rewards, destructive profile migrations, join blocks, and scope expansions.
- **Strict Asset Protection (DEC-008):** Never guess on core design or assume missing assets do not exist; if an asset is not found, report BLOCKED with search details rather than building a substitute.
- **Provenance Tagging:** Any asset or model created by agents following explicit approval must carry a `BuiltBy` attribute and be recorded in task evidence.
- **Token Economy & Small Lanes:** Tasks must remain tightly scoped (<15 files read, <60 tool calls per lane); agents read targeted line ranges and grep rather than traversing entire trees.
- **Pragmatic Code Standards:** User-facing UI, player-critical gameplay, server authority, and data stores demand rigorous care; internal plumbing may prioritize rapid completion over perfection.
- **Quality Gates:** Code changes must pass StyLua formatting, introduce zero new Selene errors (warnings are non-blocking), and compile cleanly via `rojo build default.project.json` outside the repo.
