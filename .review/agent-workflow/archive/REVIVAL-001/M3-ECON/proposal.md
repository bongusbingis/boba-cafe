# M3-ECON: Economy proposal — keeper-owned, for Jack's M3 gate

> Every number in this document is **PROPOSED** and **PENDING JACK**.
> Nothing here is decided. Nothing here is implemented.
> Settled by revival-plan §4.5, §4.6, §6.3 and DEC-014 (full plan M1–M7; Jack approves every number).
> Lane: read-only. No `.luau` file was changed, no gate was run, no Studio session was used.

## 0. Terminology

- **PROPOSED (Jack)** — a value the keeper models and Jack must approve before implementation.
- **PENDING JACK: En** — a numbered gate question in §6 below. Jack's "no" keeps the status quo described in the question's consequence line.
- **TUNING** — a non-economy gameplay constant (spawn gaps, patience seconds). Listed only where it touches earn rates.
- **UNKNOWN** — no code or plan value exists to cite. Per the lane's STOP-AND-ASK rule the value is left blank, not invented.

## 1. Sources table (every BobaBucks/XP source as coded or planned)

| # | Source | Value (PROPOSED unless noted) | Citation |
|---|--------|-------------------------------|----------|
| S1 | Per-serve base pay, Boba Teas | 3 BB per item — PROPOSED (coded placeholder) | `src/shared/Configuration/CustomerConfig.luau:84-85` (`PAY_TABLE`, M1.4e; note the file contains the `["Boba Teas"]` key twice with the same value — harmless duplicate, last wins) |
| S2 | Per-serve base pay, Coffees | 2 BB per item — PROPOSED (coded placeholder) | `CustomerConfig.luau:86-87` (both `Coffees` and `Coffee` spellings alias the same value) |
| S3 | Per-serve base pay, Hot Cocoas / Teas | 2 BB per item — PROPOSED (coded placeholder) | `CustomerConfig.luau:88-91` |
| S4 | Per-serve base pay, Pastries / Grab | 1 BB per item — PROPOSED (coded placeholder) | `CustomerConfig.luau:92-93` |
| S5 | Plan proposal: basic order pay | 5–8 BB — PROPOSED, plan-only (higher than the coded 1–3 placeholders above) | `revival-plan.md` §4.5 (lines 242-250); tension with S1–S4 is gate question E1 |
| S6 | Grade multiplier | Perfect 1.0, Close 0.5 — PROPOSED (coded) | `CustomerConfig.luau:95` (`GRADE_MULT`); matches M1.2/design.md §3.5 `pay = round(base × grade × speed × combo × source)`, min 1 |
| S7 | Speed multiplier (Fast) | ×1.5 when served within 50% of patience — PROPOSED (coded) | `CustomerConfig.luau:96-97` (`FAST_MULT`, `FAST_FRACTION`); design §3.5 |
| S8 | Combo multiplier | +10% per consecutive Perfect, capped at +50% — PROPOSED (coded) | `CustomerConfig.luau:98-99` (`COMBO_STEP`, `COMBO_CAP`); design §3.5 (a Close or walkout resets it; a Wrong attempt does not) |
| S9 | Rescue bonus | ×1.5 on the rescuer's pay, below-30%-patience tickets — PROPOSED (coded) | `CustomerConfig.luau:100-101` (`RESCUE_MULT`, `RESCUE_FRACTION`); design §4.3 |
| S10 | Minimum pay | 1 BB floor — PROPOSED (coded) | `CustomerConfig.luau:102` (`MIN_PAY`) |
| S11 | Real-player order bonus | ×2 on the barista's pay — PROPOSED, plan-only (not coded) | M1.2/design.md §4.3 + §5.8; anti-farm cap (first 3 orders per customer per 10 min) PROPOSED in design Q17 |
| S12 | Shift payout | Sum of per-serve pay + tips, plus star bonus — PROPOSED, plan-only (concept SETTLED, values not coded) | revival-plan §4.5 line 237; design §5.2 (card contents); star bonus 1★ 5 / 2★ 10 / 3★ 15 BB PROPOSED in design §5.8 |
| S13 | Rush Hour pay | ×2 for 120 s at 100% Cafe Rating — PROPOSED, plan-only (not coded) | Design §5.6 (meter gains Perfect +4/N, Close +1/N, walkout −8/N, spill +3/N; resets to 60%, ≥6 min between Rush Hours) |
| S14 | Team Combo bonus | +10% pay server-wide for 60 s at chain 10 — PROPOSED, plan-only (not coded) | Design §6 (PENDING JACK Q18) |
| S15 | Pet tip boost (equipped pet) | +2% Basic / +4% Rare / +7% Epic / +10% Legendary, highest-wins in tip family — PROPOSED, plan-only (not coded) | Design §5.7 (PENDING JACK Q16); plan §4.5 silent on pet function |
| S16 | Group member perk | +10% tips — PROPOSED, plan-only (not coded) | revival-plan §4.7; free Ant Pet exists |
| S17 | Pass tip/XP perks | Barista +25%, Kitchen Leader +50% (replaces), VIP 2× daily reward — PROPOSED, plan-only (not coded; no `PassCatalog.luau` exists yet) | revival-plan §6.3 lines 360-384; stacking rule (highest-wins per family) PROPOSED at §6.3 lines 355-357 |
| S18 | XP per served item | 10 XP, +5 Perfect, +5 Fast — PROPOSED, plan-only (not coded) | Design §5.4; curve `60 + 25·L + 2·L²` per level (L1→2 = 87 XP; L9→10 = 447; L49→50 = 6,027) |
| S19 | XP per shift | +10, plus 5 per star — PROPOSED, plan-only (not coded) | Design §5.4 |
| S20 | Spill cleanup | XP + Cafe Rating (replaces Points) — SETTLED concept, values PROPOSED/plan-only | revival-plan §4.5 lines 232-233; design §5.6 (+3/N rating); `Spills.luau` `PointIncrement = 1` is the legacy Points value, not the new award |
| S21 | Premium Payouts | Robux from Premium playtime — plan-acknowledged free income, no number (Roblox-set) | revival-plan §4.6 line 272 |
| S22 | Currency plumbing | `Modify` grants/deducts without result; `TrySpendAsync` atomically checks + deducts — coded, exists | `src/server/Modules/CurrencyService.luau:24-50` (`Modify`), `:55-94` (`TrySpendAsync`; M0 fix F6 §5 satisfied in code) |
| S23 | Customer rating tip | 1–5 hearts from a real-player customer adds to tip — PROPOSED, plan-only, value UNKNOWN | Design §4.3 (PENDING JACK Q17) |

## 2. Sinks table (every BobaBucks drain as coded or planned)

| # | Sink | Price (PROPOSED unless noted) | Citation |
|---|------|-------------------------------|----------|
| K1 | Regular Pet Capsule | 75 BB — coded price string | `InventoryItemDefinitions/Capsules.luau:20-26` (`Price = " 75"`, `MinTier = "Basic"`); mirrored in `Pets.luau:164-168` shop row |
| K2 | Rare Pet Capsule | 250 BB — coded price string | `Capsules.luau:27-33` (`MinTier = "Rare"`); `Pets.luau:169-173` |
| K3 | Epic Pet Capsule | 800 BB — coded price string | `Capsules.luau:34-40` (`MinTier = "Epic"`); `Pets.luau:174-178` |
| K4 | Nametag Capsule | 150 BB — coded price string | `Capsules.luau:12-18` (`ItemType = "Nametags"`); `Nametags.luau:263-279` (1/10/50-pack rows, all `" 150"` — bulk rows look like copy-paste, no bulk discount coded) |
| K5 | Capsule odds | Tier weights coded; effective odds derived below — coded weights, derived odds PROPOSED-as-model | `Tiers.luau` (Basic 0.5, Uncommon 0.25, Rare 0.15, Epic 0.05, Legendary 0.01, Special 0); roller `CapsuleUtil.luau:17-62` (`pickWeightedRandom` with MinTier floor) |
| K6 | Hatch time throttle | 15 min active play per pet hatch, 1 at a time — coded | `CapsuleConfig.luau:4` (`PET_HATCH_DURATION = 15*60`); enforced in `CapsuleService.luau:197-239` (`StartHatch` one-at-a-time) and `:282-296` (session persist) |
| K7 | Direct cosmetics (nametags) | 150–900 BB by tier — coded prices, real data in shop | `Nametags.luau:28-249` (Basic 150s, Uncommon 200–350, Rare 400–500, Epic 600–800, Legendary 800–900); read live by `Shop/DirectCosmeticsPurchase.luau:18-67` |
| K8 | Capsule skip with BobaBucks | Price UNKNOWN — plan-only (only the Robux path exists) | revival-plan §4.5 line 239 ("in addition to Robux"); Robux Skip Hatch product `1143554452` in `ProcessReceipt.server.luau:68-85` (DEC-006: valid only while a hatch is pending; `BottomLeft.luau:273-281`) |
| K9 | Cafe upgrades sink | UNKNOWN — plan-only ("server-wide decorations", later) | revival-plan §4.5 lines 238-239 |
| K10 | Sell-back | 10/15/25/50/100 BB by tier (Basic→Legendary) — coded | `Tiers.luau:11-31` (`SellPrice`); resale softens every capsule sink above |
| K11 | Shop tabs vs data | Pets, Nametags(real), Currency(mock), Passes(mock), Featured(empty), Celebrity(legacy) | `Shop/Pets.luau:80-93` + `RandomCosmeticsPurchase.luau:83-102` (real capsule rows); `Shop/Currency.luau:18-34` (mock BobaBucks/Robux rows); `Shop/Passes.luau:26-33` (mock passes); `Shop/Featured.luau:17-22` (empty); `Shop/Celebrity.luau` (legacy pony wall, plan says retire/re-theme §4.6) |

### Derived capsule odds (model, PROPOSED — from coded weights × counted definitions)

Counts: Pets defines 23 pets (11 Basic, 6 Rare, 3 Epic, 3 Legendary; counted from `Pets.luau` `Tier =` lines; plan §6.2 cites 27 models in `SharedStorage.Pets`, so ~4 models have no definition — observation, not a proposal).
Nametags defines 23 colors (7/6/4/3/3 across Basic→Legendary).

| Capsule (floor) | Effective odds by tier (PROPOSED model) |
|---|---|
| Regular Pet (Basic floor; pool 6.58) | Basic ≈ 83.6%, Rare ≈ 13.7%, Epic ≈ 2.3%, Legendary ≈ 0.5% |
| Rare Pet (Rare floor; pool 1.08) | Rare ≈ 83.3%, Epic ≈ 13.9%, Legendary ≈ 2.8% |
| Epic Pet (Epic floor; pool 0.18) | Epic ≈ 83.3%, Legendary ≈ 16.7% |
| Nametag (no floor; pool 5.78) | Basic ≈ 60.6%, Uncommon ≈ 26.0%, Rare ≈ 10.4%, Epic ≈ 2.6%, Legendary ≈ 0.5% |

Method: pool = Σ items(tier) × weight(tier); share = items × weight / pool. Per-item odds within a tier are uniform (roller picks by tier weight, item uniformly within tier only if equal counts per tier — actually the roller weights by tier then the roll lands on entries each carrying the tier weight, so each item of the same tier is equiprobable; cross-tier shares are as above).

## 3. Balance model (minutes-of-play per sink; numbers modelled, not changed)

Basis: M1.2/design.md §5.8 implied earn rate ≈ **9 BB/min solo early on** — PROPOSED model rate, PENDING JACK (E2).
Assumptions inside that rate (all PROPOSED): base pay as in §5.8 (Boba 3, Coffee 2 +1 per Iced/Sugar option, Cocoa 2, Tea 2, Grab 1, multi-item orders sum), Perfect/Fast/Combo flowing, ~1 serve per ~20–30 s.
Caveat: the coded `PAY_TABLE` (S1–S4) has no +1 option bonuses and no multi-item order support yet, so live earn rate will sit **below** 9 BB/min until those are coded — the model below uses the design rate, flagged per sink.

| Sink | Cost | Minutes at 9 BB/min (PROPOSED model) | Plan intent (§4.5) | Verdict (PROPOSED assessment) |
|---|---|---|---|---|
| Regular Pet Capsule | 75 BB | ≈ 8 min | 10–15 min play | CLOSE — slightly fast by ~2–7 min; within tuning distance. Flag E9. |
| Rare Pet Capsule | 250 BB | ≈ 27 min | No intent stated (UNKNOWN) | NO INTENT TO CHECK AGAINST — needs one (E9). |
| Epic Pet Capsule | 800 BB | ≈ 85 min (~1.4 h) | 2–3 h (120–180 min) | PRICES OUT OF INTENT — ~35–95 min too cheap; the prestige sink arrives in one session instead of spanning sessions. Flag E9. |
| Nametag Capsule | 150 BB | ≈ 17 min | No intent stated (UNKNOWN) | NO INTENT TO CHECK AGAINST (E9). Bulk rows (10/50 packs at `" 150"`) have no discount — likely copy-paste; Jack to confirm intent (E10). |
| Direct Legendary nametag | 800–900 BB | ≈ 90–100 min | None stated | Priced like an Epic capsule for a deterministic item — reasonable premium shape, Jack to confirm (E10). |
| Capsule skip (BB) | UNKNOWN | Unmodellable | "In addition to Robux" (§4.5) | UNKNOWN — E11. |
| Cafe upgrades | UNKNOWN | Unmodellable | "Later" (§4.5) | UNKNOWN — E12. |

XP-curve check (PROPOSED model from design §5.4, PENDING JACK E13): L1→2 needs 87 XP; first shift (≈5 serves × ~17 XP + 10 shift = ~95 XP) hits L2 in shift 1 — matches "L2 in the first shift". Cumulative to L10 ≈ 2,235 XP ≈ 12 shifts ≈ 1 h — matches "L10 by end of day 1". Cumulative to L50 ≈ 114k XP ≈ 38 h regular play — matches "~1 month". The curve is internally consistent with all three §4.5 targets; no flag.

Hatch-throttle interaction (observation, coded): at 15 min active play + 1-at-a-time (`CapsuleConfig.luau:4`, `CapsuleService.luau:197-239`), a player earning 9 BB/min can afford a Regular capsule every ~8 min but can only hatch one per 15 min — the time gate, not the price, is the binding constraint on pet inflow early. If Jack lowers capsule prices, the hatch queue still throttles; if he raises them, price binds first.

## 4. Monetization list (developer products + passes; every price PENDING JACK)

### 4a. Developer product set (revival-plan §4.6 lines 262-268; all PROPOSED)

| # | Product | Status | Price question |
|---|---|---|---|
| D1 | BobaBucks packs | Proposed; shop tab exists but is mock data (`Shop/Currency.luau:18-34`) | E14: Robux price per BB tier |
| D2 | Skip hatch (Robux) | Exists: product `1143554452` (`ProcessReceipt.server.luau:68-85`, `BottomLeft.luau:273-281`) | E15: Robux price of a skip |
| D3 | Direct capsule purchase (Robux) | Proposed; no product id exists | E16: which capsules + Robux prices |
| D4 | 30-min personal 2× tips | Proposed; no code exists | E17: Robux price; stacks-or-highest-wins vs passes |
| D5 | Server-wide "Boba Party" (2× tips or Rush Hour 10 min + buyer announced) | Proposed; no code exists | E18: Robux price; cooldown between parties |
| D6 | Tip-jar donation (reuse legacy `Donate!` ids if still on sale) | Proposed; legacy ids not found in repo (no `Donate!` product id appears in `src/`) | E19: which ids; verify on-sale state on the dashboard |
| D7 | Dev-product catalog gap | Universe 312310157 products can't be listed without auth | Precondition (not a number): Jack exports/confirms the live product list before M3 (revival-plan §6.3 lines 386-387) |

Prices are read from `GetProductInfo`, never hard-coded (revival-plan §4.6 line 270) — SETTLED plumbing rule, not a number.

### 4b. Pass catalog + legacy remap (revival-plan §6.3 lines 349-384; all perks/prices PROPOSED)

`Gamepasses.luau` defines **11** passes (Barista 6202153, Kitchen Leader 15243046, Faster Walk Speed 12385742, Instant Brew 12385760, VIP 12385781, Nametag Customizer 29083693, Emote Pack 219651061, Star Employee 219650999, Flying Mop 219651106, Uniform Remover 219651224, Water Pack 219651161). No `Listed`/`Legacy` flags and no `PassCatalog.luau`/`Perks.luau` exist yet — the §6.3 shape (one config + one perk resolver, owners keep perks whether listed or not, highest-wins stacking, Legacy Supporter fallback title) is plan-only.

Gap — passes named in §6.3 with **no entry** in `Gamepasses.luau` (counts in the packet header: ~14 on-sale incl. these + ~34 off-sale legacy; the table below is the verifiable gap list):

- Referenced with on-sale prices but missing: Unlimited Stock (43707849, 149), Mop Whack (40973940).
- Off-sale legacy missing (remap targets): Senior Barista (6202144), Staff Assistant (6202139), Premium Lounge (2126368), More Quests (12385834), x2/x4 Multiplier (7564248/7564221), Double Storage (14067346), Unlock All Pets (8022138), Name Color Changer (7692868), Rainbow Pack (12385796), Rainbow Trail/Name/Overhead (7105859/7105851/4185499), GOLD Overhead Tag (4185488), Heart NameTag (8168950), Headless Head (14067340), Korblox (12385818), Golden Boba / Red Balloon / Balloon ×3 / Heart Tool / Selfie Stick / Hoverboard tool grants, Water Pack siblings (Jet Ski ×2, Party Boat, Waterslide, Drop Tower, Beach Pass, Unlimited Fun Pass), Unlimited Song Requests ×2, Donation, UNUSED.
- Pass-tab shop UI is mock (`Shop/Passes.luau:26-33` — Barista/Shift Lead/Manager/VIP/2×/Premium rows match neither `Gamepasses.luau` nor §6.3); §4.6 requires wiring every tab to real data with zero dead buttons (release gate, not a number).

## 5. What this lane did not decide (explicit non-decisions)

- No base pay, multiplier, bonus, price, odds, XP, or Robux value in §§1–4 is approved. All await §6.
- The S5-vs-S1–S4 tension (plan 5–8 BB vs coded 1–3 placeholders) is referred to Jack (E1), not resolved here.
- The Epic-capsule intent miss (§3) is modelled and flagged, not re-priced here.
- UNKNOWNs (BB skip price, cafe-upgrade sink, customer-heart tip value, Rare/Nametag intent targets, live dev-product list) are left blank per the STOP-AND-ASK rule.

## 6. Gate questions for Jack (numbered; each with proposal + consequence of "no")

- **E1 — Base pay scale.** Proposal: adopt §5.8 bases (Boba 3, Coffee 2 +1/Iced/Sugar option, Cocoa 2, Tea 2, Grab 1, multi-item sums) as the live starting point, replacing the M1.4e 1–3 placeholders (`CustomerConfig.luau:83-94`). If no: placeholders stay dev-only and the earn rate underpinning this whole model is void — re-model before pricing anything.
- **E2 — Implied earn rate ≈ 9 BB/min.** Proposal: accept as the balance anchor for §3. If no: every minutes-per-sink figure above is void — supply the target rate and the model is re-run.
- **E3 — Perfect tip +50% shape.** Proposal: Perfect 1.0 / Close 0.5 grade with Fast ×1.5 (`CustomerConfig.luau:95-97`). If no: specify the grade/speed shape; S6–S7 change.
- **E4 — Combo +10%/step, cap +50%, reset rules.** Proposal: as coded (`COMBO_STEP/CAP`) and design §3.5. If no: specify step/cap/reset; S8 change.
- **E5 — Real-player ×2 with anti-farm cap (first 3 orders/customer/10 min).** Proposal: approve shape + cap (design §4.3/Q17). If no: real-player orders pay normal rate and the social incentive disappears.
- **E6 — Rescue ×1.5.** Proposal: as coded (`RESCUE_MULT`, 30% threshold). If no: rescues pay base rate; co-op incentive weakens.
- **E7 — Shift star bonus 5/10/15 BB.** Proposal: design §5.8 values. If no: specify values or drop the bonus; S12 change.
- **E8 — Rush Hour ×2 pay, 120 s.** Proposal: design §5.6. If no: Rush Hour is spectacle-only; S13 removed from earn rate.
- **E9 — Capsule prices (75 / 250 / 800 / Nametag 150) AND the Epic intent miss.** Proposal: confirm prices; note the model shows Epic at ~85 min vs the 120–180 min intent — either raise Epic toward ~1100–1600 BB at 9 BB/min or amend the intent to ~1.5 h. Also set intent targets for Rare and Nametag (currently UNKNOWN). If no (keep 800): record the intent as changed to ~1.5 h; the "2–3 h" line in §4.5 is superseded.
- **E10 — Direct cosmetic prices (150–900 by tier) + bulk Nametag rows.** Proposal: confirm the tier ladder; confirm whether 10/50-pack rows should discount (coded all `" 150"`). If no: specify the ladder and bulk behavior.
- **E11 — BobaBucks capsule-skip price.** Proposal: name a BB skip price (UNKNOWN today; Robux skip `1143554452` exists). If no: skip stays Robux-only; K8 stays off the BB balance sheet.
- **E12 — Cafe-upgrades sink scope/price.** Proposal: define at least the first upgrade + price, or defer explicitly. If deferred: late-game BB has no large sink; inflation risk accepted.
- **E13 — XP curve (`60 + 25·L + 2·L²`, 10/+5/+5 per serve, +10+5★ per shift).** Proposal: approve; model hits all three §4.5 targets. If no: specify curve; S18–S19 and the §3 XP check change.
- **E14 — BobaBucks pack Robux prices.** Proposal: Jack names Robux per BB tier (D1; tab currently mock). If no: no currency sale at launch.
- **E15 — Skip-hatch Robux price.** Proposal: Jack names it (product exists). If no: product stays unpriced/unprompted.
- **E16 — Direct-capsule Robux prices.** Proposal: Jack names capsules + prices. If no: capsules are BB-only.
- **E17 — 2× tips (30 min) Robux price + stacking.** Proposal: Jack names price; default highest-wins with pass tip boosts (§6.3 stacking). If no: product cut.
- **E18 — Boba Party Robux price + cooldown.** Proposal: Jack names both. If no: product cut.
- **E19 — Tip-jar donation ids.** Proposal: Jack confirms which legacy `Donate!` ids are still on sale for reuse (none found in repo). If no: tip-jar cut at launch.
- **E20 — Pass perk values + legacy remap (§6.3 table).** Proposal: approve per-pass perks (Barista +25%, Kitchen Leader +50%, VIP lounge/2× daily, etc.), highest-wins stacking, Legacy Supporter fallback. If no per item: that pass grants the fallback title only.
- **E21 — Pet tip boost +2/4/7/10% (Q16).** Proposal: approve tier values in the tip family. If no: pets are purely cosmetic; S15 removed.
- **E22 — Group perk +10% tips.** Proposal: approve. If no: no group bonus; S16 removed.
- **E23 — Team Combo +10%/60 s at chain 10 (Q18).** Proposal: approve. If no: team combo is spectacle-only; S14 removed.
- **E24 — Starter capsule (free Regular at end of shift 1, Q15).** Proposal: approve. If no: no free capsule; first-hatch hook (design §5.7: hatch completes ~17:30) does not exist and early retention model changes.
- **E25 — Sell-back prices (10/15/25/50/100 by tier).** Proposal: confirm coded `SellPrice` ladder. If no: specify ladder or disable resale (resale currently softens every sink in K1–K4/K7).
- **E26 — Capsule odds (weights + floors).** Proposal: approve coded weights (`Tiers.luau`) and MinTier floors, i.e. the §2 derived-odds table including ~0.5% Legendary from Regular. If no: specify weights/floors; K5 and any published odds change.

## 7. Sources consulted (all read, none modified)

- `.review/agent-workflow/tasks/REVIVAL-001/revival-plan.md` §4.5 (lines 231-253), §4.6 (255-275), §6.3 (348-387)
- `src/server/Modules/CurrencyService.luau` (whole — `Modify` + `TrySpendAsync` both exist)
- `src/server/Modules/CapsuleService.luau` (whole — costs are in config, not here; 15-min/1-at-a-time enforced here)
- `src/shared/Configuration/CapsuleConfig.luau`, `GamepassConfig.luau`, `Gamepasses.luau` (whole each)
- `src/shared/Configuration/CustomerConfig.luau` (`PAY_TABLE` + mults, lines 79-102), `src/shared/UI/Pages/Shop/` (Currency, Passes = mock; Pets/Nametags = real; Featured = empty; Celebrity = legacy)
- `M1.2/design.md` §§2–5.8 (pay/payout intent, XP curve, economy table)
- Supporting: `CapsuleUtil.luau`, `Tiers.luau`, `Capsules.luau`, `Pets.luau`, `Nametags.luau`, `Spills.luau`, `ProcessReceipt.server.luau:32-85`, `BottomLeft.luau:273-281`
