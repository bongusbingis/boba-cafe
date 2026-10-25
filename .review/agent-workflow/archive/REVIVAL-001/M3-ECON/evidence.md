# M3-ECON evidence (RUNBOOK step 5)

RESULT: PROPOSED — keeper economy proposal written for Jack's M3 gate; 26 numbered PENDING JACK questions (E1–E26); no number decided, no code changed, no gate run, no Studio.

Proposal: `.review/agent-workflow/tasks/REVIVAL-001/M3-ECON/proposal.md`
- §1 sources table: 23 entries (S1–S23), each with a code or plan citation.
- §2 sinks table: 11 entries (K1–K11) + derived effective capsule odds modelled from coded tier weights × counted definitions (23 pets, 23 nametag colors).
- §3 balance model: minutes-of-play per sink at the design §5.8 rate (≈9 BB/min). Flags: Epic capsule ≈85 min vs 120–180 min intent (PRICES OUT OF INTENT); Regular ≈8 min vs 10–15 min intent (CLOSE); Rare/Nametag/BB-skip/upgrades have no stated intent (UNKNOWN). XP curve verified internally consistent with all three §4.5 targets.
- §4 monetization list: 7 developer-product rows (D1–D7) + pass catalog gap list (11 passes in `Gamepasses.luau`; Unlimited Stock 43707849 and Mop Whack 40973940 + ~30 off-sale legacy ids named in §6.3 have no entry).
- §6 gate questions: E1–E26, each with proposal + consequence of "no". Count: 26.
- UNKNOWNs left blank per STOP-AND-ASK (BB skip price, cafe-upgrade sink, customer-heart tip value, Rare/Nametag intent targets, live dev-product list requiring Jack's dashboard export).

CHANGED: no `.luau` file changed (read-only lane). New files only:
- `.review/agent-workflow/tasks/REVIVAL-001/M3-ECON/proposal.md`
- `.review/agent-workflow/tasks/REVIVAL-001/M3-ECON/evidence.md` (this file)

Checks run: none (read-only lane per packet; Studio NOT RUN).

## Terra review returned (2026-10-17; recommendations only)

Terra reviewed E10, E16, E18, and E22. These recommendations are not Jack approvals and do not resolve the corresponding decisions.

- **E10 bulk Nametags:** Recommend 10-pack = 1,350 BB and 50-pack = 6,000 BB. Keep only the approved 150-BB single capsule available until stack grant/consume behavior, purchase wiring, capacity handling, and reward insertion failure behavior are fixed. Evidence reviewed: `src/shared/Configuration/InventoryItemDefinitions/Nametags.luau` currently prices 1/10/50 rows at 150; `src/client/Modules/RandomCosmeticsPurchase.luau` renders rows without purchase callbacks; capsule hatch currently removes the whole item record; capacity is 10. Jack must choose prices and implementation scope.
- **E16 paid capsules:** Do not ship paid-random capsule purchases until PolicyService enforcement and numeric odds disclosure exist. Roblox paid-random policy applies to Robux and Robux-purchased currency. Terra recommends a free first-shift Regular capsule and deterministic Nametag path for restricted players; no direct-pet catalog exists. The repository does not track capsule acquisition provenance, so eligibility of previously earned versus paid capsules remains an implementation ambiguity. Product IDs, receipt mapping, policy failure behavior, and odds disclosure remain unresolved. Jack's authorization to add a Robux path does not waive platform policy or settle those details.
- **E18 Boba Party:** Recommend one 10-minute Party Rush with a 10-minute cooldown after it ends (20 minutes start-to-start), no overlapping/stacking with earned Rush or another Party; an earned Rush cannot run during Party/cooldown. If a paid receipt arrives during an active Party, extend that Party by 10 minutes rather than refusing the purchase. Jack must approve the behavior.
- **E22 group benefit:** Recommend retaining the existing one-time Ant Pet group award as the sole non-tip group benefit, with a persistent user-initiated join prompt and server-side membership recheck/claim. Existing grant evidence: `src/server/Modules/DataService/PlayerSetup.luau` (group 3174578 and `FreeItemsRedeemed.GroupPet`). Any UI must fit existing `docs/STYLE.md` and DEC-013 conventions. Jack must confirm the benefit and prompt behavior.

Terra identified Roblox documentation relevant to E16: Paid Random Items policy, PolicyService API, and GroupService `PromptJoinAsync` API. No repository changes or tests were performed by Terra. No human approvals were inferred.

## Jack approval of Terra recommendations (2026-10-17)

Jack approved Terra's E10, E16, E18, and E22 recommendations in chat. The durable decision is DEC-029 in `../../../decisions.md`; detailed approved scope is summarized in `answers.md` Batch 5. Approval does not mean these features are implemented or tested. E16 source/provenance enforcement still requires a technical design review; Creator Hub product IDs/pricing remain Jack-configured prerequisites for purchase wiring.

