# Architectural & Optimization Decisions

Newest first. Each entry is `## <GOAL> / DEC-###: <title>` with Date, Source, and Decision. Prime is the only writer. Numbering continues; never reuse a number.

## REVIVAL-001 / DEC-032: Milestone 4 Retention & Return Loops Design Specifications

- **Date:** 2026-10-18.
- **Source:** Jack (direct answers via `/grill-me` interactive alignment session).
- **Decision:**
  - **Daily Login Streak:** 7-day repeating cycle. Days 1–7 escalate BobaBucks (50, 75, 100, 125, 150, 200, 300) with pet capsules on Day 4 (Regular Pet Capsule) and Day 7 (Rare Pet Capsule). Resets to Day 1 after Day 7 completion or after a 48-hour absence (20-hour claim cooldown). VIP pass (12385781) grants a 2× BobaBucks bonus on all claimed daily rewards.
  - **Daily Quests:** 3 daily quest slots (base) + 1 bonus slot for owners of Star Employee (219650999) or More Quests (12385834). Quests draw from core gameplay actions: Prepare Boba, Serve Customers, Clean Spills, Serve Real Players, Complete Shifts. Star Employee receives 1 free reroll per day; additional rerolls cost 50 BobaBucks (available to all players).
  - **Hidden Treasure Chests:** Shared world spawns across the 15 authored nodes in `Workspace.OldScriptables.ChestNodesFolder`. 3–5 active chests in the world at a time. Opening a chest claims it for that player, awards 35–100 BobaBucks (with a 15% capsule roll chance), increments `Statistics.TreasureChestsFound`, awards badge 2124774045 ("Treasure Chest!"), and respawns a chest at a random free node after 90 seconds.
  - **Leaderboards:** In `Workspace.OldScriptables.LeaderboardsFolder.Monthly`, replace the retired "Most Staff Points" board with "Most Orders Served". The 5 monthly boards are: Most Tips, Most Boba Bucks, Most Orders Served, Most Active, and Top Donators.
  - **Veteran Title:** Players who own any legacy Boba Cafe badge awarded prior to the revival fresh start receive a "Veteran" overhead title displayed in `PlayerOverheads`.
  - **Cleanliness Board Scoping:** Do not wire the in-world Cleanliness Board SurfaceGui in the cafe; Cafe Rating and Rush Hour status remain displayed exclusively on the top-centre HUD bar.
  - **Server Events:** Support 3 scheduled and staff-hosted events: Rush Hour (10 min), Karen Rush (10 min high-stakes Karens), and Treasure Frenzy (10 min fast chest respawns). Staff rank >= 10 can trigger an event with a server-wide cooldown.

## REVIVAL-001 / DEC-031: Simplest viable saved BobaBucks compensation

- **Date:** 2026-10-17.
- **Source:** Jack's direct instruction in chat: “dont do any overcomplicated refund logic just go with the simplest viable solution,” responding to the failed capsule-grant refund/accounting policy question.
- **Decision:** Use one additive `PendingBobaBucksRefund` amount in the existing profile, rely on `Profile:Reconcile()` for the default on existing profiles, save the obligation before issuing compensation, retry it on join and before another capsule purchase, and update `BobaBucks` plus `BobaBucksSpent` together when settling it. Do not add a per-purchase refund ledger or a new transaction service. This does not authorize paid capsule release or runtime validation.
## REVIVAL-001 / DEC-030: PET-COMPLETION receipt-path scope extension

- **Date:** 2026-10-17.
- **Source:** Jack's direct instruction in chat: “continue implementation,” in response to Prime's request to add `src/server/Scripts/ProcessReceipt.server.luau` to PET-COMPLETION's write scope.
- **Decision:** Extend the existing PET-COMPLETION packet to include `ProcessReceipt.server.luau` solely to preserve `HatchId` and `MinTier` when Skip Hatch advances a pending hatch timer. No Skip Hatch pricing, reward, eligibility, receipt handling, or other behavior changes are authorized by this scope extension.
## REVIVAL-001 / DEC-029: Jack approves Terra's E10, E16, E18, E22 recommendations

- **Date:** 2026-10-17.
- **Source:** Jack's direct approval in chat: “i approve terras recs”. Applies to Terra's recommendations recorded in `tasks/REVIVAL-001/M3-ECON/evidence.md`.
- **Decision:**
  - **E10:** Approve 10 Nametag capsules for 1,350 BB and 50 for 6,000 BB. Do not expose bulk purchase rows until stack grant/decrement, purchase wiring, capacity handling, and reward insertion failure behavior are implemented and reviewed. Keep the approved 150-BB single capsule path available.
  - **E16:** Approve the compliance gate: no paid-random capsule purchase path ships before PolicyService restriction enforcement and numeric odds disclosure are implemented. For restricted players, use the free first-shift Regular capsule and deterministic Nametag option; do not invent direct pet offers. Detailed handling of capsule acquisition provenance and paid/earned-currency enforcement still needs technical design review before implementation.
  - **E18:** Approve Boba Party as a 10-minute Rush Hour with a 10-minute cooldown after it ends (20 minutes start-to-start), no overlap/stacking with earned Rush or another Party, and an accepted paid receipt during an active Party extending it by 10 minutes.
  - **E22:** Approve the existing one-time Ant Pet as the sole non-tip group benefit, with a persistent user-initiated join prompt and server-side membership recheck/claim. UI must follow `docs/STYLE.md` and DEC-013.
- This approves the recommendations, not Creator Hub configuration. Jack configures Creator Hub prices; product IDs remain prerequisites wherever purchase/receipt wiring requires them. DEC-028 is superseded for these E10/E16/E18/E22 details. No test or implementation result is implied by this decision.
## REVIVAL-001 / DEC-028: M3 E9, E16-E23 answer batch

- **Date:** 2026-10-17.
- **Source:** Jack's direct answers in this session to the remaining M3-ECON questions.
- **Decision:**
  - **E9:** Keep the approved Rare (250 BB) and Nametag (150 BB) capsule prices; no play-time target is required.
  - **E10:** Jack requested Prime's recommendation for bulk pricing and wiring. Exact 10/50-pack prices and purchase behavior remain open pending Terra review and Jack's final decision.
  - **E16:** Approve adding a Robux purchase path for capsules; defer Creator Hub prices to Jack. Implement Roblox PolicyService/paid-random-item compliance. Terra is reviewing the safest alternative for restricted players. Product scope, IDs, and any work that depends on the compliance design remain pending review/evidence; no purchase wiring is started by this decision alone.
  - **E17:** Defer the 30-minute 2× tips product; direct real-customer-to-barista tipping is no longer central to the game's current loop.
  - **E18:** Include Boba Party as a 10-minute Rush Hour. Defer its Creator Hub price; cooldown/overlap behavior remains open for Terra's recommendation and Jack's decision.
  - **E19:** Defer the tip jar; no dashboard ID lookup requested now.
  - **E20:** Approve the defined pass mappings in revival-plan §6.3. Defer the x2/x4 multiplier values, Unlock All Pets reward, and Unlimited Stock restock effect. No unspecified perk is inferred.
  - **E21:** Approve pet tip boosts of +2% / +4% / +7% / +10% for Basic / Rare / Epic / Legendary tiers.
  - **E22:** Approve the group-benefit concept with an explicit join-group prompt; tips are excluded. Exact benefit remains open for Terra's recommendation and Jack's decision. Existing one-time GroupPet award must be considered to avoid duplicating it.
  - **E23:** Approve Team Combo +10% server-wide pay for 60 seconds at a 10-serve chain.
- No code was changed by these answers. E10 recommendations and E16/E18/E22 review do not grant automatic implementation authority; the paid-random compliance design and any remaining human choices must be reconciled first.

## REVIVAL-001 / DEC-027: E15 Skip Hatch Robux price deferred

- **Date:** 2026-10-17.
- **Source:** Jack's direct answer in this session to M3-ECON proposal E15.
- **Decision:** Defer deciding/configuring the Robux price of the existing Skip Hatch developer product. No Terra recommendation, Creator Hub change, or code change is requested. Leave the product path as it is; its launch price/prompt status remains unresolved pending Jack's Creator Hub configuration.

## REVIVAL-001 / DEC-026: E14 BobaBucks pack price recommendations approved

- **Date:** 2026-10-17.
- **Source:** Jack approved Terra's E14 recommendations in this session and specified that he will configure product prices in Creator Hub; the in-game UI must use live Marketplace product metadata as its price source.
- **Decision:**
  - Keep the current mock pack quantities and use these as the recommended Creator Hub default prices: 50 BB = 25 R$; 150 BB = 59 R$; 500 BB = 149 R$; 1,000 BB = 249 R$; 5,000 BB = 999 R$.
  - Jack will configure prices in Creator Hub. Do not hardcode Robux prices in runtime code or UI. Current Roblox API guidance marks `GetProductInfo` deprecated; use `MarketplaceService:GetProductInfoAsync(productId, Enum.InfoType.Product)` (or the documented bulk product metadata API where appropriate) for live display pricing.
  - This approval is for the recommendation and annotation only. It does not supply product IDs, authorize purchase/receipt wiring, or approve Creator Hub changes by Prime. Developer-product IDs/catalog and purchase grant implementation remain prerequisites for future wiring.

## REVIVAL-001 / DEC-025: M3 skip hatch and cafe upgrades deferred

- **Date:** 2026-10-17.
- **Source:** Jack's direct answers in this session to M3-ECON proposal E11 and E12.
- **Decision:**
  - **E11 — BobaBucks hatch skip deferred.** Keep the existing Robux-only Skip Hatch product path for now. Do not add a BobaBucks skip price or purchase path.
  - **E12 — Cafe-upgrade sink deferred.** Do not define or implement cafe upgrades as an economy sink in this gate. The late-game BobaBucks sink gap remains an accepted open economy concern; any later upgrade proposal must establish its scope, price, effect, and persistence/ownership behavior before implementation.
  - E11–E12 are answered as deferred, not approved for implementation. E14–E23 and the remaining E9/E10 subquestions remain open; no dependent work is authorized by this decision.

## REVIVAL-001 / DEC-024: M3 answer record reconciliation

- **Date:** 2026-10-17.
- **Source:** Jack's direct confirmation in this session (“B”), confirming both `M3-ECON/answers.md` Batch 1 and DEC-023 are accurate. No Claude transcript was available or inspected.
- **Decision:**
  - E1–E8 and E13 are approved as recorded in `M3-ECON/answers.md` Batch 1.
  - DEC-023's answers are confirmed: E9 raises the Epic Pet Capsule price to 1200 BB and keeps Regular/Rare/Nametag prices as recorded; E24 approves one free Regular Pet Capsule after the first shift, server-side, once, through the inventory API, without blocking shift completion or play on failure; E25 keeps the coded sell-back ladder; E26 keeps capsule odds as coded.
  - E10 keeps direct Nametag prices and approves fixing the bulk rows, but exact bulk prices/discount, quantity mechanism, and purchase wiring remain undecided. E9's Rare/Nametag intent targets also remain undecided.
  - E11–E12 and E14–E23 remain unanswered. No work depending on these open answers is authorized.
  - This entry reconciles the conflicting “Still open” statement in DEC-023 for E1–E8. The M3 proposal and completion ledger remain historical records of the original proposal-only state and are not rewritten.

## REVIVAL-001 / DEC-023: M3 capsule economy answers (E9, E10, E24, E25, E26); Prime takeover

- **Date:** 2026-10-17.
- **Source:** Jack, direct answers in chat to the interrupted Claude (Opus) Prime's M3-ECON gate questions (`.review/agent-workflow/tasks/REVIVAL-001/M3-ECON/proposal.md` §6). Takeover Prime: Muse Wonder 1.0. A Muse Spark Scout lane verified the code paths read-only; no `.luau` file was changed by this decision.
- **Where Claude left off:** M3-ECON proposal complete (26 PENDING JACK questions E1–E26, nothing decided, nothing implemented). M1/M2 lanes through FIX-SOUNDGROUPS are in `completed.ndjson`. The live board still carried only the stale waiting tasks JACK-STUDIO, Q-DOCS-M1, M1.4a and M1.6.
- **Decision:**
  - **E9 — Epic capsule to 1200.** Epic Pet Capsule price changes from 800 to **1200 BobaBucks** (≈133 min at the modelled 9 BB/min, inside the 2–3 h prestige-sink intent). Regular 75, Rare 250 and Nametag 150 are unchanged. Implementation touches both price mirrors: `src/shared/Configuration/InventoryItemDefinitions/Capsules.luau` (`["Epic Pet Capsule"] Price = " 800"`) and `src/shared/Configuration/InventoryItemDefinitions/Pets.luau` (`Capsules` shop row `Price = " 800"`). Intent targets for Rare and Nametag were asked in E9 and were **not** answered; they remain open and must not be invented.
  - **E10 + E25 — Fix bulk, keep rest.** Direct nametag prices by tier (150 Basic to 900 Legendary, `src/shared/Configuration/InventoryItemDefinitions/Nametags.luau`) are kept. Sell-back by tier (10/15/25/50/100, `Tiers.luau` `SellPrice`) is kept; no change needed there. The Nametag capsule bulk rows (`Nametags.luau` `__index.Capsules`: 1 / 10 / 50 packs, all `Price = " 150"`) are a defect and must be fixed — they may not stay at 150. **Not decided:** the exact bulk prices or discount, and the quantity mechanism. Scout found the shop row in `src/shared/UI/Pages/Shop/RandomCosmeticsPurchase.luau` renders those rows with no `OnClick` and there is no `Count`/quantity grant path, so a bulk fix needs a purchase-wiring decision from Jack before a Mason lane is dispatched (DEC-008: do not guess prices). Recorded as blocked on that one choice, below.
  - **E26 — Capsule odds approved as coded.** Tier weights and `MinTier` floors stand as coded (`Tiers.luau`: Basic 0.5, Uncommon 0.25, Rare 0.15, Epic 0.05, Legendary 0.01; roller in `src/shared/Inventory/CapsuleUtil.luau`). Derived odds (Regular: Basic ≈84%, Rare ≈14%, Epic ≈2.3%, Legendary ≈0.5%; Rare: Rare ≈83%, Epic ≈14%, Legendary ≈2.8%; Epic: Epic ≈83%, Legendary ≈17%; Nametag: Basic ≈61% down to Legendary ≈0.5%) are approved. No code change.
  - **E24 — Starter capsule approved.** Every player gets one free Regular Pet Capsule at the end of their first shift, so the first pet hatches about 15 min later in the first session (`CapsuleConfig.luau` hatch is 15 min active play). Not yet coded: `ShiftService` already fires `ShiftEnding`/`Client.ShiftEnded` with a shift summary and `ProfileTemplate.Statistics.ShiftsCompleted` exists, but no first-shift grant or one-time guard exists yet. The grant must be server-side, one-time per player, and go through the inventory API; it must never block shift completion or play if it fails.
  - **Still open (not answered, not decided):** E1–E8, E11–E23 fully, plus the two sub-questions above (Rare/Nametag intent targets in E9; exact bulk prices/mechanism in E10). Prime (Wonder) will present the next batch; nothing in those numbers may be implemented until Jack answers.
- **Model routing for the follow-up work (Jack, this session):** Prime is Muse Wonder 1.0 and reserves Wonder for critical gameplay design, open-ended questions and planning. Muse Spark is the default worker lane (Scout/Mason/Gauge/Sentry/Quill packets). This supersedes the Claude-lane hints (`opus`/`sonnet`/`haiku`) in older board entries and DEC-007/DEC-016 for new dispatches; existing packets remain valid.

## REVIVAL-001 / DEC-022: Studio latitude, counter anchoring, no player-player collision
Date: 2026-10-17. Source: Jack, in session.
Decision:
- Prime may make additive or destructive changes that serve the game (e.g. new ProfileTemplate stats) without per-change approval. The AGENTS.md approval list (economy, publishing, uploads, secrets) still applies.
- Studio placement is rough; Jack fine-tunes by hand. Don't spend tokens searching for locations. NPC Entry is at (4.6,-6.8,323.9) for testing.
- Anchor NPC and counter placement to `workspace["Ordering System"]` (registers and CustomerAreas). v4 positions do not transfer.
- Register hogging, option 1: players don't collide with each other (`CafePlayers` vs `CafePlayers` non-collidable, set in CustomerService). Other options (serve range, soft station claims, NPC-to-barista routing) stay open until after testing.
- M2-AREAS: Jack places the gate parts (copy `Gate_Template`) and the desert walls himself.

## REVIVAL-001 / DEC-021: M2 PACK-2 answers

- **Date:** 2026-10-17.
- **Source:** Jack (direct answers in chat).
- **Decision:**
  - **2nd ticket (L5):** stacks under the first, using the same OrderTicket component.
  - **Cafe Rating meter:** a small bar top-centre, directly under the TopBar time pod. It copies existing STYLE.md patterns.
  - **L35–L50 rewards:** existing nametag colours and particles, plus a **level title system**. A text title from `Progression.luau` (names PROPOSED, Jack edits them) shows on the overhead under the name, in the existing PlayerOverheads style. Group-rank titles (D8) stay as they are.
  - **Rating and XP placeholders (PROPOSED, in config):**
    - Clean a spill: +3% rating and 5 XP.
    - Fast serve: +1%.
    - Walkout or wrong serve: −2%.
    - Spills slowly drain the rating.
  - **Desert walls:** the Rigger proposes the line in Studio; Jack approves it from one capture.
  - No NPC seating in M2. "Angry" reuses v4's Confused animation.
  - Karen's description lives at `ReplicatedStorage.SharedStorage.NPCStorage.Karen` (IMPORT-V4 / RIG-1), not `SharedStorage.NPCs`.
  - ShiftCard sits top-right (accepted).

## REVIVAL-001 / DEC-020: M1.5b STYLE questions answered

- **Date:** 2026-10-16.
- **Source:** Jack, asked directly in chat.
- **Decision:**
  - Q1 row state markers: plain-text glyphs in the two existing OrderTicket colours.
  - Q2 Close colour: new yellow Styles token approved.
  - Q3 phone collapse: TouchEnabled + tap-header collapses the ticket.
  - Q4 header (cup viewport, patience bar, "Shift n · k/N"): in M1.5b scope; viewport image approved.
  - M1.5b unblocked and re-dispatched. Mode: build per spec without sloppiness, keep cheap gates, defer verification to the end.

## REVIVAL-001 / DEC-019: Jack does all in-game testing

- **Date:** 2026-10-16.
- **Source:** Jack: "In-game testing should be left to me. Tell me when to test things."
- **Decision:**
  - Agents never run Play tests, TestEZ runs or playtests in Studio.
  - Studio is used only for authoring (Rigger) and saving.
  - Lanes write "Test for Jack" steps in their note.
  - Prime tells Jack when a testable slice is ready, with a short checklist. M1.6 is Jack's playtest.

## REVIVAL-001 / DEC-018: Implement first, verify later; minimal process

- **Date:** 2026-10-16.
- **Source:** Jack: "this is not a full, detailed workflow needing evidence for everything you do; stay away from trivial tasks that eat up tokens… Implement first, verify if needed long afterwards."
- **Decision:**
  - Lanes build. Verification (Studio, Gauge, Sentry) is batched late: one pass before the M6 playtest, plus a Sentry review of purchase and receipt code in M3.
  - Evidence is a 5-line note.
  - Prime does no per-lane ledger or board bookkeeping beyond leases.
  - Packets stay short (DEC-016 still applies: they exist for the weaker-agent handoff).

## REVIVAL-001 / DEC-017: Speed over polish for code players don't see; lanes stay small

- **Date:** 2026-10-16.
- **Source:** Jack: "You do not have to write good, clean code; if it's not user-facing, it doesn't have to be absolutely perfect, it can use bad practices or quick solutions. Getting this done as quick as possible is more crucial…" He also flagged UI-CONV reaching 315k tokens as too large "for what is a rather trivial task".
- **Decision:**
  - **Quality bar:**
    - Careful work is needed only where players feel it: UI (STYLE.md), gameplay behaviour, and errors that reach players.
    - Also careful: anything that protects money, data or server authority (purchases, receipts, saves, remotes).
    - Everything else may be quick, duplicated or ugly.
  - **Gate:** run `stylua <changed files>` (auto-format, no thought), then `gate`.
    - Blocking: a `rojo build` failure, or new Selene **errors**.
    - Not blocking: new Selene warnings. Record them; don't fix them.
  - **Tests:** write specs only for money, data or authority logic, or where they are nearly free. No specs that mirror the implementation. Runtime proof comes from the batched Gauge run.
  - **Reviews:** Sentry reports only player-visible defects, exploits, data or money loss, and continued-play violations. Code-quality and style findings are not reported and not tracked.
  - **Lane size:**
    - Packets name the exact files to read.
    - Agents read line ranges and use grep, never whole trees.
    - A lane that needs more than about 15 files read, or more than about 60 tool calls, stops and returns what it has.
    - Docs and research lanes run on haiku or sonnet, with a hard scope.

## REVIVAL-001 / DEC-016: Token economy; every lane runs from a packet a weaker agent can execute

- **Date:** 2026-10-16.
- **Source:** Jack: "It is extremely important you save on tokens; delegate to less powerful agents (i.e. Sonnet, Haiku, where applicable) and make sure that if I run out of usage early, I can delegate to meta muse or google gemini; another less-powerful, stupider agent that may not be as capable but can follow explicit instructions that don't have open-ended design decisions."
- **Decision:**
  - **Routing (tightens DEC-007):**
    - haiku: mechanical edits, moves, greps, docs formatting.
    - sonnet: everything else, including Sentry reviews and the Keeper economy proposal.
    - opus: Prime only, plus a Sentry review of receipts or purchases (M3).
    - Prime reads evidence with `head` and `grep` only.
  - **Packet-first:** before dispatching any lane, its full contract is written to `tasks/REVIVAL-001/packets/<ID>.md` (format in `packets/README.md`). The agent prompt is only "execute packet <ID>".
    - A packet holds no open design decision. Anything undecided becomes a `STOP-AND-ASK` line naming the exact question.
    - A packet must be executable by a non-Claude agent (Muse, Gemini) that follows explicit steps.
  - **Runbook:** `tasks/REVIVAL-001/RUNBOOK.md` tells any agent, Claude or not, how to pick the next packet, run the gates, write evidence, and when to stop.
  - **Design ahead of execution:** while Claude capacity remains, design-heavy work (M2–M4 contracts, the M3 economy proposal) is turned into packets before the build work runs out, so that a weaker agent can finish the build if usage runs out.
  - **Gate tooling** lives in the repo at `.review/agent-workflow/tools/wsl/` (WSL shims for the Windows rokit binaries), not in a session scratchpad.

## REVIVAL-001 / DEC-015: Asset and existing-content questions approved (Q7–Q9, Q19, Q22–Q26)

- **Date:** 2026-10-16.
- **Source:** Jack approved, in bulk, Prime's recommendations built on S3 (`tasks/REVIVAL-001/S3/evidence.md`).
- **Decision:**
  - **Q7 spawns:** move inside, at most 30 studs (walking) from the Clear Cup station. A Rigger places them in one Studio pass and Jack checks one capture.
  - **Q8 NPC route:** the same pass authors `workspace.Assets.NPC` (Entry, Path, Queue, and Counter spots beside the kitchen, per the approved Q2), reusing `OldScriptables.NPCFolder` nodes where they fit (clone, never destroy).
  - **Q9 trash cans:** wire the dev place's 6 cans with v4 behaviour. A "Use" prompt shows "Throw Away?" Yes/No and discards the held tool. A tool with `NotDisposable` is refused.
  - **Q19:** the 8 extra syrups, the smoothies and fruit tools, and the 13 pastries with no stations stay off the launch menu.
  - **Q22:** no sink. Teas and Water use the dev place's existing `Assets.Kitchen.Givers.Coffee Machine.Water` spout as the water step.
  - **Q23:** use whatever `SoundService.SFX.Kitchen` already has. A missing sound stays silent; no substitutes.
  - **Q24:** import v4's `ReplicatedStorage.SharedStorage.CleanlinessStorage` (spills Boba, MeltedPopsicle and Donut; tools; Sparkles; Animations) into the dev place, and point SpillService at it. The Rigger authors spill areas on the new map.
  - **Q25:**
    - NPCs use the dev place's 10 `SharedStorage.NPCs` looks, plus v4's Karen description.
    - NPCs get v4's Wave, Confused and Idle animations. No new animations: the bubble and patience bar carry mood.
    - Baristas wear v4's Default uniform while clocked in.
  - **Q26:** Celebrity stays a Robux shop tab, wired in M3 with Jack's prices. No celebrity-visit system.
  - **Bonus:** reuse v4's `CustomerConfig` dialogue pools (Greeting, WrongOrder, Leaving; Default and Karen) as NPC bubble lines.
  - Imported v4 instances get a `BuiltBy="REVIVAL-001-import-v4"` attribute, and are listed in the evidence.

## REVIVAL-001 / DEC-014: Launch cut is the full plan (M1–M7)

- **Date:** 2026-10-16.
- **Source:** Jack chose "Full plan M1–M7" over "Lean + return hooks" and "Lean launch", after a summary of the differences.
- **Decision:**
  - Release happens only after M1 through M6 in `revival-plan.md` §8, with their exits met.
  - That includes, before launch: M4 retention (streak, quests, leaderboards, events, D8 rank titles, moderation and hosting); the M2 variants and Cafe Rating; and the M5 console, StreamingEnabled and legacy-cleanup items.
  - Speed comes from parallel lanes and early Keeper work, not from cutting scope. The M3 economy proposal starts during M2.

## REVIVAL-001 / DEC-013: UI replicates existing style; conventions documented in STYLE.md

- **Date:** 2026-10-16.
- **Source:** Jack: "document all existing UI conventions such that they can be easily replicated with no deviation from the current existing UI's style. Do not invent new UI style; utilize what already exists style-wise and replicate it if new UIs are needed."
- **Decision:**
  - `docs/STYLE.md` becomes a complete, source-derived replication spec. Task UI-CONV writes it.
  - New UI reuses existing tokens, components and patterns only.
  - A new token, component or visual pattern needs Jack's approval. If no existing pattern fits, the builder stops and asks.
  - UI lanes (M1.5b, M1.4f, the end-of-shift card, shop wiring) start only after UI-CONV is accepted, and their reviews check against that spec.

## REVIVAL-001 / DEC-012: Studio housekeeping delegated; Studio verification used sparingly

- **Date:** 2026-10-16.
- **Source:** Jack: "don't worry about saving or trivial things like this… you have explicit permission to use computer use tools to click the save button yourself if needed." Also: "Studio review is expensive and should be used sparingly to save on my claude usage."
- **Decision:**
  - The "jacks project" place is saved, so the M0.1 world wiring is durable.
  - Prime may save the place itself, including through computer use, along with other trivial Studio housekeeping, without asking. Publishing to the live place is still Jack's call.
  - Studio runtime and visual checks are batched: one Gauge run per milestone (DEC-007, "test only what can't be inferred"). Lens captures happen only where a visual can't be judged from the source plus STYLE.md. Rigger work is bounded to authoring that has a named contract.
  - Jack connected Rojo and the Studio MCP and will restart the session to load it. Before that restart, background lanes must finish (they die with the session), and the kickoff must be current.

## REVIVAL-001 / DEC-011: M1.2 design recommendations approved

- **Date:** 2026-10-16.
- **Source:** Jack approved, in bulk, the recommendations for Q1–Q6, Q10–Q18 and Q20–Q21, as written in `tasks/REVIVAL-001/M1.2/design.md` §10.
- **Decision:**
  - Those answers are settled design, and `PENDING JACK` markers for them may be built.
  - Economy values (Q5, Q6, Q15, Q16, Q17 numbers) remain PROPOSED placeholders until the M3 economy gate.
  - Still open: Q7–Q9, Q19 and Q22–Q26 (asset locations and existing content). S3 brings candidate answers from the v4 place.
  - Still open: the launch cut (which milestones ship at release).

## REVIVAL-001 / DEC-010: Prime transfer after the halted overnight run; Windows/WSL environment

- **Date:** 2026-10-16.
- **Source:** Jack: "taking over for a halted agent… Assume the old agent session cannot be recovered; go off of recent diffs/commits as well as the /.review." Goal restated: release the game to players, as quickly as possible without being sloppy.
- **Decision:**
  - The overnight Prime (DEC-009) is treated as stopped. Its last durable state is commit `cbf5271` plus `night-log.md`. The in-flight M1.5cd lane and the S2 Rigger packets left nothing on disk and are relaunched or replanned. `board.json` was rebuilt from the evidence (it is gitignored and did not travel).
  - The repo now lives in a Windows checkout used from WSL. Windows git has `core.autocrlf=true`, so WSL git reports CRLF-only changes on tracked files. Files are left as they are. Lanes always pass explicit file lists to the gate.
  - Gate in WSL: source `<scratchpad>/env.sh`, then run `gate <files>`. The scratchpad shims run the Windows rokit binaries (rojo 7.7.0 from tool storage), translate paths, and have stylua check CR-stripped content. On committed files this reproduces the Mac results.
  - `default.project.json` (gitignored) was removed by the `main` → `uhweifh` checkout. It was recreated from ARCHITECTURE.md §4 with mappings only: no `src/replicatedFirst` (absent on this branch), and no baseplate or lighting properties (so `rojo serve` never pushes them into the authored place).
  - Studio lanes wait until Jack enables the Studio MCP for this project and confirms that the M0.1 world wiring in "jacks project" was saved.

## REVIVAL-001 / DEC-009: Overnight autonomous Prime run (2026-10-14 night)

- **Date:** 2026-10-14.
- **Source:** Jack: "You are piloting for the next ~8 hours… full permissions and authority as prime… do whatever required that is defensible to work without me here."
- **Decision:** Prime runs M1 autonomously while Jack is away, bounded as follows.
  - **Build only answer-robust work**, meaning work whose value survives any answer to Q1–Q26: M1.3c/d, M1.5a–d, the NPC lifecycle (M1.4d) behind the world contract, M1.4b config without pay values, measurement events.
  - **Not built:** assignment and serve (Q1/Q2), payouts and pay values (Q5/Q6, economy gate), world authoring for spawns and NPC routes (Q7/Q8), and anything else marked `PENDING JACK`. For Q7–Q9, a read-only Rigger prepares candidate packets with captures so Jack can answer quickly.
  - **Still Jack's:** DEC-008, publishing, pushing, saving the place, economy numbers, and destructive data changes. Local checkpoint commits on branch `uhweifh` are allowed (no push).
  - **Cost:** sonnet for build lanes, opus only for one Sentry review. At most 3 lanes at once. One batched Gauge run at the end.
  - **Context freshness:** Prime keeps `tasks/REVIVAL-001/night-log.md` current after every lane, and rewrites `kickoff-next-session.md` at the end, so a fresh session can resume from disk.

## REVIVAL-001 / DEC-008: No guessing on core design or existing content

- **Date:** 2026-10-14.
- **Source:** Jack. M0.1 built a new `SyrupDispenser` because the plan assumed none existed. Jack's own model was in ServerScriptService's Archive/Services/KitchenService. In Jack's words: "that should have been a question asked to me rather than guessing like it did which produced a low quality results. Do not make guesses for such core design decisions like this without confirming with me."
- **Decision:**
  - **Missing or misplaced content:** if code expects an asset (model, tool, animation, sound, area) and an agent can't find it where expected, that is a question for Jack. It is never a reason to build a substitute.
    - Agents report BLOCKED with what they searched.
    - Prime asks Jack where the asset is, or whether it exists.
    - "Not found by search" is never recorded as "does not exist".
  - **Core design decisions** are Jack's: loop structure, what gets cut or kept, roles, progression shape, station or recipe flow, and the look of any new content. Specialists propose them as questions with a recommendation, marked `PENDING JACK`, and nothing is built on them until Jack answers.
  - **Assets agents build** (only after Jack confirms none exists) carry a `BuiltBy` attribute, and are listed in the task evidence.
  - **Prime's check:** before any lane builds, Prime scans the contract for assumptions about existing content and design intent, and turns them into questions for Jack.
- **Applies retroactively:** every `BuiltBy`-tagged instance from M0.1 is listed for Jack's review (M0.11).

## REVIVAL-001 / DEC-007: Workflow efficiency changes

- **Date:** 2026-10-14.
- **Source:** Jack ("do as many defensible changes as you want"; "use sonnet (and maybe haiku) where applicable"; no manual setup on his end). Prime chose the changes after this session's lessons.
- **Decision:**
  - **Model routing:** sonnet is the default for bounded lanes (Mason, Gauge, Quill, Scout). Haiku is for mechanical work: exact-text edits, file moves, log greps. Opus is only for Sentry, Architect, Forge, and Rigger work that needs judgment.
  - **Kickoffs are checked against evidence:** before writing a kickoff or handoff, and at session start, Prime confirms that each "next step" has no evidence file already, or that the existing file predates the source it covers (`find src -newer <evidence>`). Completed evidence that is still current is reused, not redone.
  - **Rojo live-sync rule:** `src/` edits sync into Studio, so code lanes must not run during a Gauge Studio session whose evidence depends on that code. Worktree isolation (`Agent isolation: worktree`) is used for code lanes only once a committed base exists, because worktrees start from HEAD.
  - **Code gate is `scripts/gate.sh <files>`:** it reports no new Selene or StyLua findings versus HEAD and runs `rojo build` outside the repo. `rokit.toml` pins selene and stylua so the shims resolve.
  - **TestEZ without editing the file:** in Edit mode Gauge runs `workspace:SetAttribute("RunTests", true)`, plays, then clears the attribute. The Studio-only guard is in `RunTests.server.luau`.
  - **Evidence files start with a `RESULT:` line**, so Prime can read status with `head -3`.
  - **Docs lanes run alongside verification by default**, accepting a small follow-up edit if a repair changes a contract.
  - **Testability:** new receipt, economy and validation logic goes in ModuleScripts that specs can require. Logic inside `.server` scripts can't be tested.
- **Not adopted:** standing approval for M1 design lanes. That is Jack's gate (M1 go).

## REVIVAL-001 / DEC-006: Skip Hatch is invalid without an active hatch

- **Date:** 2026-10-14.
- **Source:** Jack ("dont allow purchase if their not hatching; that shouldnt be possible theoretically so its an invalid purchase").
- **Decision:**
  - The client must never prompt the Skip Hatch product unless a hatch is pending.
  - If a receipt arrives anyway with no hatch pending, the server treats it as invalid: it grants nothing and does not return `PurchaseGranted` (return `NotProcessedYet`, so Roblox keeps the receipt unconsumed).
  - No skip credit is stored.
- The 5 sound assets that fail permission checks are Jack's to fix later. They are not tracked as agent work.

## REVIVAL-001 / DEC-005: Reuse the existing map; never delete it

- **Date:** 2026-10-13.
- **Source:** Jack.
- **Decision:**
  - Do not delete the existing map. Build the new gameplay in it.
  - Limiting where players can go or what they can see is the preferred way to focus the experience (a Forge item for M2).
  - A completely separate new area is allowed only if Prime is certain it will look hand-made rather than AI-generated or sloppy. The default is no.
  - Legacy `OldScriptables` content is moved or cloned, never destroyed, and is backed up before it is moved.

## REVIVAL-001 / DEC-004: Join kick removal approved; M0 and M1.1 approved to start

- **Date:** 2026-10-13.
- **Source:** Jack ("confirm, this was just a debug thing"; "approved").
- **Decision:** The rank-<4 kick in `src/server/init.server.luau` was a debug lock and is removed in M0. M0 (foundation) and M1.1 (order-spec design) are approved to start.

## REVIVAL-001 / DEC-003: Revival plan v2 adopted as the working plan

- **Date:** 2026-10-13.
- **Source:** Prime (second session) review of code, Studio place, and live Roblox data; Jack asked for a comprehensive plan to test-ready and release, no changes yet.
- **Decision:** `tasks/REVIVAL-001/revival-plan.md` replaces the phase plan in `handoff.md` §4 (handoff kept as history). Milestones M0–M7; M1 "serve one NPC" vertical slice proves the loop before breadth. World wiring reuses `workspace.OldScriptables` (legacy givers, ordering system, NPC nodes already aligned with the new map) instead of building proxy models.

## REVIVAL-001 / DEC-002: Release target, legacy data, passes, ranks, resources

- **Date:** 2026-10-13.
- **Source:** Jack (answers to Prime's questions).
- **Decision:**
  - Ship over the same place 718328620. Full fresh start: no legacy currency or items are carried over.
  - Every legacy gamepass is remapped to a perk. The pass catalog must let any off-sale legacy pass be listed again without code changes.
  - Group ranks become titles, moderation, and event hosting, with no gameplay gating.
  - Solo + AI agents only: no commissioned art and no ad budget.

## SETUP-001 / DEC-001: Agent workflow adopted; tooling baseline recorded

- **Date:** 2026-10-12.
- **Source:** Jack's request to port the agent workflow and documentation structure into this repository.
- **Decision:** `AGENTS.md`, `docs/AI_AGENT_WORKFLOW.md`, `CONVENTIONS.md`, `ARCHITECTURE.md`, `SYSTEMS.md`, and `STYLE.md` are the governing documents. Task evidence lives under `.review/agent-workflow/tasks/<ID>/` and moves to `archive/` when finished.
- **Tooling baseline (before any agent change):** `rojo build default.project.json` succeeds. Selene reports 201 errors and 63 warnings. `stylua --check src` flags 99 files. No Studio TestEZ run was performed (`TESTS_ENABLED = false`). The gate for a change is no new findings in the files it touches, not a clean repository.
- **Not verified:** All system descriptions in `SYSTEMS.md` were read from source and have not been exercised in Studio.




