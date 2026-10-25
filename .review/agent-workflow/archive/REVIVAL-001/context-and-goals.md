# REVIVAL-001 — Problem statement, design goals, and context (verbatim + curated)

This file preserves *why* the work exists, in the user's own words where possible.
**Read this before `handoff.md`** — the handoff is what we found and planned; this is
what we were asked and why. Do not "improve" the verbatim sections; challenge them in
`handoff.md` or a review doc instead.

Task folder: `.review/agent-workflow/tasks/REVIVAL-001/` · Board: `.review/agent-workflow/board.json`

---

## 1. Original user prompt (verbatim, first message)

> Review the agent workflow and this codebase to get a comprehensive understanding of
> this game; this is a new/rescripted version of a roblox cafe simulator game. The
> traditional structure of these games relies on chat: players order from cashier ->
> cashier submits order -> barista claims it in the kitchen and makes it -> customer
> picks up order; imagine starbucks roleplay on Roblox. This traditional structure also
> is very "professional" rp; players all start as customers, you have to join the group
> and actually attend a training session to be ranked in the Roblox group before being
> able to access the kitchen and counter to take/make orders. A recent roblox chat
> update killed all of the engagement and ccu for this game, as players can no longer
> chat outside their age group which kills the gameplay of a game designed around chat
> itself. WE ARE MOVING AWAY FROM THE PROFESSIONAL RP STANDARD. We want to make this as
> much of a "game" rather than a "roleplay experience" as possible; I have already
> largely started with the infrastructure for this, but I abandoned this project for a
> while and am now coming back to it. Examine it in its current state against the
> context I have given you and get back to me (read-only) with your findings. My main
> priority is reviving the game (currently sitting at 3 ccu) - I want to make money
> and get players again. Here is a link to the game itself and its associated group for
> additional context; the community is very large (2m+ members) but the game is dead,
> so there is clearly a problem with the structure/gameplay. Any proposed changes are
> fully in-scope; you are not limited. https://www.roblox.com/games/718328620/Boba-Cafe
> https://www.roblox.com/communities/3174578/Boba#!/about - this is somewhat of a
> "hail mary' task.

## 2. Design goals, as stated by the user

Distilled from the prompt and later answers — these are *goals*, not findings:

1. **Revival first.** Game sits at ~3 CCU. Get players back. ("My main priority is
   reviving the game… I want to make money and get players again.")
2. **Kill the professional-RP standard.** No more: start-as-customer → join group →
   attend a training session → get group-ranked → only then access kitchen/counter.
   The training/rank pipeline is the problem, not a feature to restore.
3. **"Game, not roleplay experience."** Systems over social performance. A player
   should be able to *play* the loop without other people cooperating socially.
4. **Chat independence is the hard constraint.** The Roblox age-segmented chat update
   "killed all of the engagement and ccu" for a chat-designed game. Any new core loop
   that requires cross-age-group chat is a non-starter.
5. **Monetization matters.** Money is an explicit goal (not an afterthought);
   `docs/CONVENTIONS.md` independently ranks monetization, engagement, retention,
   CCU as the four highest product priorities.
6. **The community is the asset.** Group 3174578 has 2M+ members (per user; "very
   large (2m+ members)"). The game is dead despite this — "there is clearly a problem
   with the structure/gameplay," not with audience size.
7. **Scope is open.** "Any proposed changes are fully in-scope; you are not limited."
   ("This is somewhat of a 'hail mary' task.") — balanced by Jack-approval gates in
   `docs/CONVENTIONS.md` / `docs/AI_AGENT_WORKFLOW.md` for economy numbers,
   publishing, failure/join blocks, destructive migrations, secrets.
8. **Infrastructure exists but the project was abandoned mid-rescript.** "I have
   already largely started with the infrastructure for this… but I abandoned this
   project for a while and am now coming back to it." (Findings in `handoff.md`
   assess how much of that infrastructure is actually usable.)

## 3. The traditional loop being replaced (for agents without Roblox-RP context)

- Customers (everyone starts as one) speak their order to a human cashier via chat.
- Cashier submits the order into the ordering system; it appears on staff screens.
- Barista claims it in the kitchen, physically crafts the drink/food with tools and
  stations, deposits it at a pick-up area.
- Customer walks to pick-up, collects tools, consumes/sits/socializes. Staff also
  clean spills; Karens and events add variety.
- Authority = Roblox group ranks (Customer → Trainee/Cashier → Barista → Kitchen
  Leader → MR/HR/SHR), earned via scheduled training sessions announced in the group.
  Status grind = rank prestige + staff rooms/offices + admin proximity.

Why it died, in the user's framing: the loop needs *chat across age groups* and
*staffed, trained humans present at the same time*. Age-segmented chat broke the
ordering conversation; an empty game can't bootstrap trained staff; CCU spirals.

## 4. User decisions made during this session (all user-confirmed)

| # | Decision | How it was made |
|---|---|---|
| D1 | Core loop = **NPC customers + real customers** (hybrid). NPCs are the always-on baseline; real customers order via **chat-free tap/kiosk UI**. (Options rejected: NPC-only; real-players-only-no-chat.) | `request_user_input`, 2026-10-12 |
| D2 | **No new commissioned map.** "Getting an entirely new map rebuilt by a 3d modeler is out of the question currently, so we have to work with what we have." Five screenshots supplied showing ordering counter / kitchen / main cafe / outside. | User interjection |
| D3 | Roblox Studio MCP is available; open place is **"jacks project"** (placeId `89999123284040`). | User interjection |
| D4 | A Part named **`KITCHEN`** now sits roughly center-kitchen (approx (40, -6.4, 263) — verify live). | User interjection |
| D5 | Plan before build: "Build the plan and ask me any specific questions as needed." (Delivered: `handoff.md` §4; still awaiting phased execution go-ahead per-phase.) | User message |

## 5. Problem framing the review used (to challenge or keep)

These were the reviewer's working frames — successors may disagree, but should say so
against this text, not a strawman:

- **Root cause hypothesis:** the game sells *status through gated social labor*.
  Gating was the marketing (prestige) but also the single point of failure: it needs
  concurrent trained humans + open chat. Remove the gate and the status must be
  re-created inside the game (levels), or veterans lose their identity hook.
- **Design rule adopted in the plan:** *a solo player who never chats must have a
  complete fun loop in minute one; other players and staff roles are a bonus, not a
  requirement.* NPC customers make the job-sim playable at 1 and at 50 players.
- **The 2M-member group flips role:** from gatekeeper (rank source) to rewards source
  (daily bonus / exclusive pet / multiplier) + reactivation megaphone.
- **Chat-era store copy is anti-selling:** the live description (fetched 2026-10-12)
  still advertises "Take our Cashier quiz," "Attend a training by saying '!apply',"
  "be ready for KARENS," DevForum handbooks — i.e., homework as marketing. Relaunch
  copy must sell the job-sim loop instead. (Full live description captured in the
  review turn; re-fetch before P5 — don't trust this snapshot.)
- **Success criteria (plan):** new player earns within 60s with zero chat/group;
  fun at 1 and 20+ players; ≥1 real purchase path works end-to-end (idempotent);
  zero dead shop buttons; no join kick / rank gates / startup-error paths shipped;
  relaunch package (store rewrite, group shout, comeback codes, 2x weekend) ready.

## 6. Operational context worth not losing

- Two Roblox repos exist on this machine — **verify cwd**:
  `/Users/jackcrowell/Desktop/boba-cafe` = this project;
  `/Users/jackcrowell/repos/ouch` = a different "Ouch!" project (the session's default
  workspace root). One handoff write initially landed in the wrong repo; fixed + flagged.
- Tooling: Rojo CLI 7.5.1 (Rokit) + 7.7.0 (cargo); VS Code extension also runs
  `rojo sourcemap --watch`. All 7.x speaks protocol 4. Two connection incidents
  diagnosed in `handoff.md` §5 — the current Rojo state is **unverified**:
  re-run `curl http://localhost:34872/api/rojo` before trusting any sync claim.
- Live place (718328620) vs dev place ("jacks project", 89999123284040) are different
  universes — nothing proven about the dev place transfers to live.
- Agents' approval boundary (Jack only): failure/join blocks, publishing, uploads,
  economy/prices/probabilities/rewards, destructive migrations, secrets, scope widening.

## 7. Reviewer's cover note (opinion, flagged as such)

The foundation (data, inventory, capsules, pets, dialogs, UI shell) is genuinely
reusable, and the new map is finished-quality scenery — the gap is a *game loop that
assumes staffed humans and open chat*, plus a shop that takes no money. The smallest
revival slice is: anyone can play → one NPC can be served → payout + first level →
one capsule actually purchasable → playtest. Everything else multiplies that slice.
The hail-mary isn't a feature; it's the 2M-member relaunch moment landing on a loop
that works in an empty server.
