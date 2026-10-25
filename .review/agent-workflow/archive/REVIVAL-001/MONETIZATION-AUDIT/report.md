RESULT: PASS

# Boba Cafe — Monetization, Engagement & Revenue Optimization Audit

- **Date:** 2026-10-22
- **Auditor:** Prime (acting monetization strategist / economy designer / product analyst)
- **Source state:** branch `uhweifh`, working tree as Rojo-synced to the beta place (placeId 128511401637461). 28 modified files + 7 untracked (moderation/logging feature in flight). Economy values marked PROPOSED are placeholders until Jack approves them.
- **Method:** source read of all economy/monetization configs, services, and shop/menu UI; live beta place inspection (read-only); targeted web research (links inline). Observations vs inferences are labeled throughout.

---

## 1. Executive summary

Boba Cafe is a **roleplay cafe with a strong core loop** (order → prepare → serve → pay → progress → collect) and a **clean, well-guarded economy**. It is under-monetized relative to its systems: the game already has a currency, a cosmetics catalog, a hatching loop, passes, quests, daily rewards, leaderboards, server events and a working receipt pipeline, but **most of the revenue surface is either unwired or one-time-only**.

The three biggest commercial findings:

1. **There is no recurring revenue product.** Every paid product today is one-time (14 gamepasses, BB packs, skip hatch, Boba Party, Rush Hour, donations). Roblox's own discovery algorithm now rewards **repeat spend across days** (7-day spend days / 7-day Robux spent), and platform-wide ~90% of payers repurchase monthly. A **season pass and/or a light subscription** is the single largest revenue gap.
2. **The hard part (trust and purchase integrity) is already done, and done well.** `ProcessReceipt` is idempotent, save-confirmed, and fail-closed; `CurrencyService` has atomic spend; `BobaBucksShortfall`/`PassUpsell` already implement ethical, click-only upselling; live Marketplace prices are used everywhere. New revenue products are **cheap to add** because the plumbing exists — mostly config + a `ProductActionMap` entry.
3. **Several built surfaces are dead or inert:** the Celebrity tab renders "1 Month / 3 Months / 6 Months" purchase buttons with no click handler; Points have no sink and the Points shop is hidden; Robux-buyable capsule products are stubbed nil; `OffSale` flags exist but no seasonal/limited cosmetics use them. Fixing these is mostly wiring, not new systems.

Priority direction (detailed in §10): **instrument first**, then **(a) season pass, (b) first-purchase/starter bundle, (c) wire the dead surfaces, (d) seasonal/limited cosmetics, (e) expand sinks and status goods.** Respect the game's identity: pay for **convenience, status and cosmetics**, never for the ability to serve or to win.

---

## 2. Existing-game audit

### 2.1 What the game is

A single-place Roblox multiplayer cafe roleplay game. Players order drinks/food; baristas (anyone clocked in) prepare them in a kitchen via recipe action sequences and serve NPC or real-player customers; spills are cleaned; everyone earns **BobaBucks (BB)** and **Points**, and collects **Pets, Nametags, Particles, Titles** from capsules, the shop, and progression.

### 2.2 Core loop and enjoyment sources

- **Serving loop:** Take Order → read the ticket → run kitchen steps (cup → syrup → tapioca → machine → pour meter) → deliver → get graded (Perfect/Close/Wrong) → get paid → see combo/tip/rating effects.
- **Progression:** XP → levels 1–50 → new drinks, ticket slots, titles, free nametags every 5 levels; shift summaries and paychecks.
- **Collection/customization:** pet hatching (15 min active-play timer), nametag colors (animated), particles, titles, uniforms, pets as followers.
- **Social/status:** group benefit (Ant Pet), friend invites, monthly leaderboards with statues, Top Donators board, server-wide Cafe Upgrades with buyer plaques, Team Combo and Rush Hour shared events, Real Orders with 1–5 star ratings.

### 2.3 Likely audience and motivations

- **Age/psychographic:** Roblox cafe-RP audience skews young (U13–U18 dominant on platform), plays on mobile (~80% of platform sessions), motivated by **roleplay identity, collecting cute items, social status, and light cooperation**. Secondary segment: older/returning players of the pre-revival Boba Cafe (the "Veteran" title and legacy badges exist specifically for them).
- **Payer segments implied by the design:** (a) pass buyers (convenience + boosts), (b) cosmetic collectors (nametag/pet whales), (c) server-boost buyers (Boba Party, Rush Hour, Cafe Upgrades), (d) donors (Top Donators). The game currently serves (a) and (d) best; (b) and (c) are partially built.

### 2.4 Onboarding / early game / churn risks

- **Good:** no join gating; first 3 NPC serves are scripted (patience off, fixed orders); first shift grants a starter pet capsule; daily rewards start immediately; level 1–2 unlocks are fast (level 2 needs 87 XP ≈ 5–6 serves).
- **Risks:** the nickname prompt (3 s delay) and data-load wait are the only first-session friction; the HUD is calm. The real early churn risk is **social**: an empty server means no queue and no rating drama, so retention depends on **fast path to "the cafe is alive"** (NPCs exist; seating is OFF pending perf). Second risk: first 15-minute pet hatch and one-slot hatch limit can feel slow on mobile sessions.

### 2.5 What is monetized today (verified from code)

| Surface | Type | State |
|---|---|---|
| Boba Bucks Robux packs 50/150/500/1000/5000 | Developer products | **Live** (IDs in `ProductIds.luau`; receipts via `BobaBuckReceipts`; excluded from leaderboard) |
| Boba Party (10 min server Rush) | Developer product | **Live** (`3300909405`) |
| Rush Hour (2 min server Rush) | Developer product | **Live** (`3318558073`) |
| Donations 5 R$ → 500k R$ (12 tiers) | Developer products | **Live** (Top Donators credited) |
| Skip Hatch | Developer product | **Live** (only while a hatch is pending, DEC-006) |
| Gamepasses | 14 listed (`PassCatalog`) | **Live**; legacy delisted ones still grant perks |
| BB-priced goods: pet capsules 75/250/1200, nametag capsule 150 / 10-pack 1350 / 50-pack 6000, deterministic nametags 150–900, particles 150–600, quest reroll 20, cafe upgrades 150/300/500 + 250/500 | Soft currency | **Live** (server-authoritative via `TrySpendAsync`) |
| Promo codes | Server config | 2 live codes (`BOBATIME` 100 BB ×500, `GRANDOPENING` 250 BB + 100 Points ×1000) |
| Group Benefit (Ant Pet) | Group join incentive | Live |
| Points shop packs | Soft currency | **Hidden** (`UIFlags.SHOW_POINTS=false`; Points have no use) |
| Celebrity membership (1/3/6 months) | Page | **Dead** — buttons render, no `OnClick` |
| Robux capsule products (NametagCapsule1/10/50) | Developer products | **Stubbed nil** — keys exist, products not created |
| Pass upsell rows (paycheck / level-up) | Gamepass prompts | Live (click-only) |

### 2.6 Constraints and missing information

- **No performance/revenue data yet** — the game is pre/at launch; no analytics dashboard numbers were available to this audit. All quantitative estimates below are illustrative.
- **Economy values are PROPOSED** (`PAY_TABLE`, variants, rating, upgrades, regulars reward are "Jack to tune" placeholders) — monetization tuning must follow Jack's economy approval.
- **Robux prices are not in the repo** (DEC-026: live Marketplace metadata only), so pack price points could not be verified; they are the primary unknown in the financial model.
- **Studio checks unverified:** seating is OFF (`SeatingConfig.ENABLED=false`); a 50-NPC perf check is pending; TestEZ currently shows 20 failures in uncommitted work (`GiveTool`, `ShiftService`, `Spill`, `LeaderboardService`).
- **Content authored in the place** is Studio-owned; new world content (e.g., furniture, private island) needs Rigger work.

---

## 3. Monetization diagnosis

### 3.1 What works

- **Purchase integrity is exemplary.** Receipts are idempotent (`PurchaseId` recorded in profile, bounded to 200), save-confirmed before `PurchaseGranted`, fail-closed for unmapped products, and Robux packs are leaderboard-excluded so money cannot buy rank. This is a strong foundation for adding revenue products without risk.
- **The soft-currency store is already the "right shape":** consumable (capsules, rerolls) + durable (nametags, particles, pets) + server goods (upgrades, parties), which matches Roblox Creator Hub guidance (mix of consumable and durable, many price points).
- **Upsell rails exist:** `BobaBucksShortfall` (shortfall → "Get Boba Bucks" → Shop) and `PassUpsell` (capped, click-only, live prices) are ethical and already wired into paycheck/level-up moments.

### 3.2 Structural gaps

1. **No recurring revenue.** Everything expires or is one-time. A season pass (per month/season) and/or a light subscription is the standard, evidence-backed fix (§6, O-01, O-02).
2. **First-purchase friction is unmanaged.** There is no welcome offer, no starter bundle, no first-purchase discount. Roblox Creator Hub explicitly recommends welcome offers; battle-pass/subscription data shows low-price first offers convert first-time buyers.
3. **Soft-currency price ladder is top-loaded for whales only.** BB packs start at 50 BB, but the cheapest useful sink is 75–150 BB; there is no sub-100 BB "starter" pack or pack bonus to make the first purchase feel generous.
4. **Dead surfaces leak demand.** Celebrity (a recurring membership with named perks) renders but cannot be bought; Robux capsule packs are stubbed; Points accumulate nowhere; `OffSale`/limited flags are unused, so there is no urgency anywhere.
5. **Server-wide goods reset every server** (Cafe Upgrades are per-server, unsaved). That is fine for decor, but it means no persistent "I own this cafe" investment surface — the strongest whale/status purchase in a roleplay game is missing (permanent, named, visible ownership).
6. **No trading or secondary market.** Roblox supports Limited items/trading; the game has collectibles with tiers and sell values but no limited-edition supply. This is a strategic unlock, not a launch item (§6, O-19).

### 3.3 Cannibalization watch

- BB packs vs play earnings: if serving pays too little, gameplay feels stingy and payers resent; if it pays too much, packs are unnecessary. Current proposed pay (≈5–15 BB/serve mid-game, up to ~30 in Rush/VIP with boosts) versus sink prices (150–1200 BB) sits in a reasonable "earn in days, buy in seconds" band. Do **not** raise sink prices without Jack's economy approval.
- Pass boosts (Tip/Xp +25/50%) vs a season pass with boosts: overlap must be resolved so the season pass does not devalue Barista/Kitchen Leader passes (§6, O-01 risk).

---

## 4. Engagement and retention diagnosis

### 4.1 Current retention systems (verified)

| System | Cadence | Hook |
|---|---|---|
| Daily Rewards 7-day streak | 20 h cooldown / 48 h reset | BB + capsules; VIP doubles BB |
| Daily Quests (3 base, +1 pass) | UTC day | BB + XP; free reroll (Star Employee) or 20 BB |
| Weekly Quests | Monday reset | Regular Pet Capsule each |
| Treasure Chests | 90 s respawn / 15 min player cooldown | 20–40 BB + 10% capsule |
| Shift summaries / paychecks | per shift (10 serves) | stars, bonus, personal bests, pass upsells |
| Level-ups | 1–50 | drinks, titles, nametags, ticket slots |
| Regulars collection | permanent | 12 named regulars, 2500 BB + title on completion |
| Events (auto every 3600 s; staff-hosted) | 10 min | Rush Hour / Karen Day / Treasure Frenzy |
| Team Combo | 10-serve chains | server-wide +10% pay window |
| Leaderboards + statues | monthly | Most Orders Served / Most Boba Bucks |
| Friend invite | permanent | +50 BB (friends + 7-day account + 5/day cap) |
| Veteran / titles | permanent | legacy recognition |

This is an **unusually complete retention stack for a small game**. The weak points are cadence depth (most systems are daily; there is little **intra-day** rhythm beyond treasure chests and rush), and **presentation** (quests are only reachable inside Menu → Quests after DEC-057 removed the HUD button; the Daily button exists but the STREAK-REMINDER is owed).

### 4.2 The biggest lifecycle opportunities

- **Day 1:** a scripted first session + starter capsule already exists. Add: a **first-session "welcome pass" moment** (show one clear offer after the first serve, not before), and make the first hatch fast (e.g., first hatch at 5 min).
- **Day 7 / Day 30:** the season pass is the standard answer; add **weekly rotating featured cosmetics** to give returning players a reason to check the shop.
- **Session frequency:** intra-day hooks (Rush Hour purchasable, treasure respawns, spill waves) exist; a **"second visit" daily reward tier or 2× first-30-minutes bonus** could deepen the same-day loop without new content.
- **Social attachment:** Real Orders + hearts + regulars are good but under-leveraged; add **co-op streaks (serve with the same barista)** and **friend leaderboards** before investing in guilds.
- **Reactivation:** no win-back exists. Promo codes are the cheap reactivation tool (already built); pair them with **push via group shout / external community posts** (external comms need Jack's approval).

---

## 5. Economy and progression audit

### 5.1 Currency flows

**BobaBucks sources (server-authoritative, all via `CurrencyService`):**

| Source | Typical amount | Reason tag |
|---|---|---|
| NPC serve pay (`Rules.Payout`) | 1–~27/serve before tips | `Gameplay` |
| Real-player serve pay (`RealOrderService`) | ×2 base, first-3-in-10-min | `Gameplay` |
| Shift bonus / streak | 5/star, 30 BB streak | `Gameplay` / `ShiftStreak` |
| Perfect pour tips | +5 each, max 2/drink | `Gameplay` (via pay) |
| Tip/Xp pass + pet tip | +2–50% of pay | (in pay) |
| Rush Hour | ×2 | (in pay) |
| Team Combo | ×1.10 window | (in pay) |
| Daily rewards | 585/7-day cycle (1170 VIP) | `DailyReward` |
| Quests | 20–75 each | `QuestReward` |
| Weekly quests | 1 Regular Pet Capsule each | (item) |
| Treasure chests | 20–40 + 10% capsule | `TreasureChest` |
| Regulars completion | 2500 once | `Regulars` |
| Friend invites | 50 each, ≤5/day | `FriendInvite` |
| Promo codes | 100–250 | `PromoCode` |
| Robux packs | 50/150/500/1000/5000 | `RobuxPack` |
| Refunds | as owed | `QuestRerollRefund`, pending BB refunds |
| Item selling | tier SellPrice 10–100 | `ItemSell` |

**BobaBucks sinks:** pet capsules 75/250/1200; nametag capsules 150/1350/6000; deterministic nametags 150–900; particles 150–600; quest rerolls 20; Cafe Upgrades 150–1700/server; (Points: no sink).

**Points:** earned from spill cleaning (1/spill) and promo codes; **no sink exists**. The Points shop is hidden. Either build a Points sink (O-08) or retire the currency display to avoid "useless currency" confusion.

### 5.2 Bottleneck math (illustrative, PROPOSED economy)

A solo barista at pacing target 2 NPCs, serving efficiently:

- **Serve pay (mid-game, combo 4, Perfect, fast):** Classic Boba base 3 × grade 1 × fast 1.5 × combo 1.4 ≈ **6 BB** (rounded). With a Legendary pet tip (+10%) ≈ 7. With Rush ×2 and a VIP ×2 it can reach ~25–30.
- **Throughput:** 15–25 serves/hour realistic → **~90–160 BB/hour of raw serve pay**, plus quest/daily/treasure amortized ≈ **+50–100 BB/hour** in a normal session.
- **Sink affordability:** Regular capsule (75) ≈ 30–60 min; Nametag 10-pack (1350) ≈ a multi-session goal; Epic capsule (1200) ≈ an aspirational 1–2 day goal; 50-pack (6000) ≈ whale/grinder territory.
- **Conclusion:** the earn/spend slope is healthy. The commercial lever is **not** squeezing earnings; it is converting the earned-BB storefront into more frequent, more desirable purchase moments (featured items, bundles, seasons) and adding Robux shortcuts.

### 5.3 Inflation and value traps

- **BB inflation is bounded** (packs inject BB; sinks remove it; there is no trading), but daily+quest+treasure passive income (~150–300 BB/day for an active player) will eventually make basic items trivial for veterans. Add **rotating premium/limited items** as the veteran sink.
- **Capsule value degrades** as the pool saturates (duplicate pets sell for 10–100 BB). Consider duplicate trade-ups (O-09) to keep capsules valuable long-term.
- **Points are dead weight.** Either give them a real sink or stop granting them (do not show a currency players can't spend).

---

## 6. Detailed opportunity catalog

Format per idea: **Concept / Player experience / Implementation / Monetization / Business case / Measurement** (scaled to importance). Ideas are combined where they overlap; variations are named. Every economy-affecting value is **PENDING JACK**.

### O-01. Season Pass ("Boba Season") — HIGH PRIORITY / STRATEGIC

**A. Concept.** A monthly (28–35 day) two-track reward pass built on existing quest/XP plumbing. Free track: small BB, a few capsule rewards. Premium track (~299–499 R$): a 30-tier track of cosmetics, BB, capsules, an exclusive seasonal pet/nametag, and **BB rebates that repay most of the pass cost** (the proven self-funding loop). Cosmetic-only premium rewards; no serve-power.

**B. Player experience.** Every serve, spill, and quest earns pass XP in the background (reuse `ProgressionService` XP signals). A HUD/Shop "Season" tab shows the track, the next reward, and the free vs premium split. Buying the premium track feels like "I was going to play anyway; now I get paid for it." Season end shows a recap and the next pass teaser.

**C. Implementation.**
- Data: add `SeasonPass = { SeasonId, XP, Premium, ClaimedTiers = { [n] = true } }` to `ProfileTemplate` (additive; reconcile).
- Server: `SeasonPassService` (Knit) — `AddSeasonXp` (hooked to the same signals as quests: `CustomerResolved`, spills, shifts), `ClaimTier`, purchase via `ProcessReceipt` `ProductActionMap` (reuse the durable receipt path). Pure logic (tier curve, reward table) in a config module + spec.
- Rewards config: `shared/Configuration/SeasonConfig.luau` with `TRACK` table; free and premium columns per tier.
- UI: new Shop tab or HUD card using only existing components (`ShopCategory` rows, `PromptButton`, `Banner`, `ProgressBar`-like rows per STYLE.md; no new tokens).
- MVP: 30 tiers, 4-week season, premium track only (no tier skips). Future: tier skips (BB), "Season + 20 tiers" bundle, seasonal quest multipliers.
- Effort: medium. The receipt, quest and progression plumbing already exists; the work is the track content and one page.

**D. Monetization.** One premium purchase per season (~299–499 R$; mobile norms suggest 299–499 R$ for Roblox passes). Include ~40–60% of the Robux-equivalent back as BB so engaged players re-buy. Recurring seasonal revenue; drives 7-day spend days (the Roblox discovery metric). Low cannibalization if premium rewards are mostly cosmetic; do not put Tip/Xp boosts in the pass (protect Barista/Kitchen Leader).

**E. Business case.** Evidence: battle passes are the dominant recurring model; Sensor Tower/Newzoo aggregations report ~12–18% conversion for well-implemented passes and currency-rebate passes drive repeat purchase (see §7). The causal chain: pass purchase → daily reason to play → more serves → more social presence → retention → next pass. Main risk: content treadmill (mitigate: 30 tiers of mostly existing-catalog cosmetics + BB; one exclusive item per season).

**F. Measurement.** Primary: premium conversion (% MAU), season pass repeat purchase. Supporting: pass XP/day, tier completion rate, D7/D30 retention of buyers vs non-buyers. Guardrails: non-buyer retention must not drop; free track must remain meaningful.

### O-02. "Barista Club" light subscription — HIGH PRIORITY

**A. Concept.** An in-experience Roblox subscription (~199–299 R$/month) of convenience perks, positioned for daily players: +1 daily quest slot, +1 free reroll/day, +25% hatch speed, double treasure cooldown speed, +50% shift XP, a monthly exclusive nametag, and a subscriber badge by the name tag. Explicitly **no** serve-power (no pay multiplier beyond existing pass families, or fold it into the Tip family at the same cap so it never stacks).

**B–C.** Reuses: quest slot logic (`QuestConfig.BONUS_SLOT_PASSES`), perk flags, hatch timer, `GamepassUtil`-style ownership cache. Roblox in-experience subscriptions bill through `MarketplaceService`; grant/revoke by subscription state (server polls or uses `PromptSubscriptionPurchaseFinished`-style events; verify current API at build time — **verify subscription APIs against Roblox docs before implementation**).

**D.** Recurring monthly revenue; targets the "plays daily, never buys passes" segment. Price it below the season pass+VIP combined value. Complements, not replaces, the season pass (subscription = convenience; pass = content track).

**E.** Subscriptions convert lower than passes but retain subscribers strongly; suits "steady daily value" games (Vectra Play summary, 2026). Risk: Roblox subscription management overhead; start with 30-day pass-style renewal via developer product if subscriptions are not available in the region.

**F.** Primary: subscriber MRR, monthly renewal rate. Guardrail: non-subscriber retention and complaint rate.

### O-03. First-purchase offer / Starter Bundle — QUICK WIN

**A.** A one-time "New Barista Kit" shown after the first serve (not before): 500 BB + 1 Regular Pet Capsule + a small exclusive nametag for ~199–299 R$ (or a one-time 50% bonus on the first BB pack). Sold as a developer product or a discounted pack.
**B.** The shortfall upsell already routes players to the shop; the starter bundle is the same flow with a better first impression.
**C.** New `ProductActionMap` entry granting via existing `BobaBuckReceipts` + `CapsuleService:GrantEarnedCapsule` patterns; a `FirstPurchaseOfferShown/Claimed` flag in profile.
**D.** Converts first-time buyers; evidence: Roblox Creator Hub explicitly recommends welcome offers; FTB conversion is a top monetization lever in F2P.
**E.** Low cost, low risk; the main risk is showing it too early (annoyance). Gate on first serve completed.
**F.** First-purchase conversion, offer take rate, subsequent 30-day payer retention.

### O-04. Wire the dead surfaces — QUICK WIN (bundle of small fixes)

1. **Celebrity membership:** wire the 1/3/6-month buttons to developer products (create products + `ProductActionMap` entries granting a `CelebrityUntil` timestamp + perks) or, if Jack prefers, repurpose the tab as a **donation/status page** (perks list already exists). Requires Jack's decision on whether Celebrity should be revived or retired.
2. **Robux capsule packs:** create the three Nametag Capsule developer products and paste IDs into `ProductIds.CapsuleRobux` (config-only after products exist).
3. **Points sink:** either add a small Points shop (uniform colors, emote variants) or hide/retire Points. PENDING JACK.
4. **Featured tab defaults:** `Featured.luau` hardcodes fallback prices (250 R$, 249 R$) — acceptable fallbacks, but ensure live fetch works (DEC-026) and add the "Best Value" framing for the BB packs row in Products.
5. **Shop category click coverage:** confirm every on-sale card has a click path (Pets cards are display-only; that is fine, but add a "Get capsules" hint).

### O-05. Seasonal / limited cosmetics with `OffSale` — HIGH PRIORITY

**A.** Rotate a "Seasonal" collection (nametags/particles/pets) every 2–4 weeks using the existing `OffSale` flags and tier system. Limited items leave the store at rotation (they can return next year), creating urgency without loot-box mechanics.
**B.** A "Seasonal" row on Shop Featured; items show a countdown and an "Leaves soon" banner (existing `Banner` + `TopBanner`).
**C.** Config-only in `InventoryItemDefinitions` + a `SeasonalConfig` with rotation dates; `OffSale` is already respected by the shop and purchase paths.
**D.** Creates repeat visit + purchase urgency; seasonal items are the standard liveops content (Roblox Creator Hub guidance; LiveOps data).
**E.** Low content cost (recolors/animations of existing nametag system are cheap); risk: over-rotating cheapens the catalog. Start quarterly.
**F.** Seasonal item conversion, shop return visits, sell-through rate.

### O-06. Persistent "Cafe Ownership" prestige goods — STRATEGIC

**A.** Extend Cafe Upgrades with **persistent, saved, named purchases**: a "Golden Plaque" (name permanently on the cafe wall across servers), custom register skin, or a purchasable "Cafe Founder" title/badge. Saved in profile, displayed server-wide from profile data.
**B.** Whale/status purchase; the buyer's name is visible to everyone, forever — the strongest social proof in a roleplay game.
**C.** Profile field (additive) + server reads it to render the plaque; purchase via `ProductActionMap`. Visuals need Studio/Rigger work for a wall model (exact path in evidence; BuiltBy attribute).
**D.** One-time high-price (~1000–5000 R$) plus the existing per-server upgrade sink. Near-zero cannibalization (different segment).
**E.** Precedent: server-naming, statues and donor boards are proven whale goods in RP games; Top Donators board already proves the audience values permanent recognition.
**F.** High-price SKU conversion, repeat donor rate, social mentions.

### O-07. Bundles & BB pack bonuses — QUICK WIN

**A.** Add pack **bonuses** (buy 500 get +50, buy 5000 get +750) as a "Most Value" banner row, and time-limited "BB + capsule" bundles (e.g., 500 BB + Rare Pet Capsule).
**B.** Makes the BB ladder feel generous and gives price anchoring.
**C.** Bonus is config + label in `BobaBuckReceipts.PACKS` (grant = base + bonus); bundle = new developer product + `ProductActionMap`.
**D.** Raises ARPPU and pack attach; matches "consumable + durable mix" guidance.
**E.** Low risk; watch refund path (grants are receipt-driven, already safe).
**F.** Pack ARPPU, bundle attach rate.

### O-08. Points: give them a job — QUICK WIN (needs Jack decision)

Either (a) **Points shop**: uniforms, emote packs, small particles, spill-cleaner tools (cosmetic only), or (b) **convert Points into a "cleanliness rank"** cosmetic ladder. Cleaning is already fun and under-rewarded (1 Point/spill); a Points sink closes the loop and justifies the currency. PENDING JACK on direction and prices.

### O-09. Duplicate trade-ups — MEDIUM

**A.** Trade N duplicate pets/nametags of a tier for one random item of the next tier (e.g., 5 Basic pets → 1 Uncommon+ roll). Sinks duplicates, keeps capsules valuable, extends collection endgame.
**B.** Inventory UI: "Trade Up" button on tier groups (existing `ItemCard`/`CapsuleTierGroup` components).
**C.** Server inventory mutation (existing `RemoveItems` + `Insert`); pure `TradeUpConfig` + spec.
**D.** Drives capsule consumption (BB sink) indefinitely; no new revenue product needed — it strengthens the existing one.
**E.** Low risk; classic collection-loop mechanic.
**F.** Trade-up usage, capsule repurchase rate.

### O-10. Intra-day retention: "Happy Hour" and second-visit bonus — MEDIUM

**A.** A daily 30-minute **Happy Hour** (e.g., 2× serve pay or 2× XP at a fixed UTC window, advertised in HUD) and a **"Come back tonight"** second-visit chest. Deepens same-day loops without new content.
**B.** HUD banner via existing `Banner`/toast; no new UI patterns.
**C.** Server attribute + `Rules.Payout` multiplier hook (one config flag); second-visit chest = a daily flag + existing chest spawner.
**D.** More sessions/day → more serve pay → more store exposure → more conversions. Roblox 2025 benchmarks emphasize **denser daily play**.
**E.** Risk: payout inflation; keep it time-boxed and mark PROPOSED.
**F.** Sessions/day, DAU/MAU, pay events during window.

### O-11. Referral program expansion — MEDIUM

**A.** Extend friend invites with a **tracked refer-a-friend ladder** (3/5/10 friends → BB + exclusive pet/title) and a **"invite back" win-back bonus** for returning friends (lapsed ≥30 days). Existing `SocialInviteService` already validates friends + account age + daily caps.
**B.** Same invite flow; ladder visible in a small "Invite" card.
**C.** Additive profile fields + ladder config; reuse the invite signal.
**D.** Acquisition is free; lapsed-friend reactivation is the cheapest win-back.
**E.** Risk: invite farming (already mitigated by caps/friends/age gates; extend the same gates).
**F.** Invite sends, joins attributed, reactivations.

### O-12. Personalization: loadout presets & custom café order card — LOW/MEDIUM

**A.** Save **outfit/loadout presets** (equipped pet + nametag + particle + title) as purchasable extra preset slots (e.g., 2 free, +3 slots for 99 R$ or 500 BB). Plus a **custom "My Usual" order card** (cosmetic) shown to baristas.
**B.** Inventory "Loadouts" tab; presets switch in one tap.
**C.** Profile `Loadouts` field + equip logic (reuses `EquipTitle`/inventory equip paths).
**D.** QoL monetization (convenience), high perceived value for RP players.
**E.** Small scope; low risk.
**F.** Preset slot purchases, equip frequency.

### O-13. VIP pass upgrade & family expansion — MEDIUM

**A.** Give the VIP pass (12385781) more visible value: a **VIP lounge spawn** (already `VipLounge` perk), a **weekly VIP gift**, and show VIP perks in the pass card. Add a **"Super Star" top-tier pass** (Star Employee + VIP perks bundle) if Jack wants a $ high-end SKU.
**B–C.** Config + small grants; verify `VipElevatorService` lounge wiring.
**D.** Raises pass ARPPU and gives the VIP pass a reason beyond the daily ×2.
**E.** Low cost; avoid perk stacking beyond existing family caps.
**F.** VIP pass attach, VIP D30 retention.

### O-14. Event monetization: scheduled "paid access" events — EXPERIMENTAL

**A.** Staff/auto events exist; add **premium event variants** (e.g., a purchasable "Golden Rush" with better treasure odds for 10 min) sold like Boba Party. Only after Jack approves event economy.
**B.** Buy → server-wide buff announced like Boba Party.
**C.** Reuse `EventProducts` + `ProductActionMap` + workspace attributes.
**D.** Repeatable server-wide spending (like Boba Party).
**E.** Social proof: one buyer benefits everyone → positive perception. Risk: event stacking complexity.
**F.** Event product attach, buyer repeat rate.

### O-15. Collections & badges as storefront — LOW

**A.** Add **collection completion bonuses** (own all Basic pets → title/badge + small BB) to the Inventory Collection page, driving capsule sales. Titles/badges exist as systems.
**B–C.** Config-driven checklist + `BadgeService`/`GrantTitle`.
**D.** Free reward that sells more capsules.
**E.** Trivial risk.
**F.** Collection completion rate, capsule purchases per collector.

### O-16. Creator/community codes (creator codes) — LOW / defer

Roblox's Creator Affiliate/creator codes can share revenue with influencers. Defer until the game has traffic; requires Jack + Roblox setup.

### O-17. Immersive ads — LOW / defer (platform-dependent)

Roblox immersive ads exist but require scale and care (young audience). Defer; revisit only if the game reaches 10k+ DAU and Jack approves.

### O-18. Trading / Limiteds / UGC — STRATEGIC / defer

Limited-edition collectibles with Roblox trading (via UGC limiteds) are the long-term status economy for RP games, but require the game to publish UGC items, Roblox approvals, and careful economy design. Not a launch item; note as the 6–12 month strategic unlock.

### O-19. Private islands / personal space — STRATEGIC / defer (content-heavy)

The Celebrity page promises "Private Island"; personal spaces are strong RP sinks but are content-heavy (Rigger/Studio). Defer until core monetization lands.

### O-20. Price localization & payment optimization — QUICK WIN

Use Roblox's built-in price localization (set prices in local currencies where supported) and ensure **prices are only shown via live metadata** (already the convention). Add **price anchoring labels** ("Best Value", "Most Popular") to packs — config-only. Also consider a **99 R$ "tip jar" developer product** near the registers (donations already exist; a small tip jar gives a micro-transaction for non-whales).

---

## 7. Evidence and precedents

Verified/attributable findings (as of 2026-10-22; treat aggregator numbers as directional, not gospel):

- **Roblox platform economics:** Standard DevEx rate is **$0.0038/Earned Robux**; a **$0.0054 rate** applies to eligible in-experience spend by age-verified US 18+ players from June 8, 2026 (Roblox DevEx docs; SEC filings). After the 30% marketplace fee, creators keep ~26–27% of player spend at the standard rate. Source: Roblox 4Q25 shareholder letter (https://www.sec.gov/Archives/edgar/data/0001315098/000131509826000009/ex991-q42025shareholder.htm), Roblox Creator Hub DevEx docs, and the Game-Ace/PropelRC summaries (https://game-ace.com?p=10518/, https://www.propelrc.com/robux-to-usd-converter-calculator/).
- **Platform payer funnel:** FY2025: 127M average DAUs, ~1.8M daily payers, bookings $6.79B, average daily bookings per DAU **$0.15** (https://fourweekmba.com/roblox-business-model/). Q1 2026: 132M DAUs, ~1.9M daily payers (~1.4% daily payer penetration) (https://dcfanalyst.com/blogs/overview/rblx-overview). Monthly paying users ~36.7M in Q4 2025 (https://coopboardgames.com?p=27247/).
- **Payer distribution is top-heavy:** GameAnalytics' 2025 Roblox Benchmark Report: top 5% of payers spend ~20–30× the bottom 50%; whales >$20/day vs median payer <$1/day; ~90% monthly repurchase platform-wide; Roblox discovery rewards **7-day spend days per user** and **7-day Robux spent per user** (https://www.gameanalytics.com/reports/2025-roblox-report).
- **Roblox's own storefront guidance:** welcome offers/discounts for first-time purchasers; consumable + durable mix; seasonal items; variety of price points; retention drives ARPDAU (https://d2gbj0c64xar4a.cloudfront.net/docs/production/analytics/monetization).
- **Battle pass evidence:** Fortnite-standard $9.99 passes; mobile passes $4.99–6.99; aggregators report ~12–18% conversion for well-implemented passes, ~18.4% of active F2P gamers buy seasonal passes, passes drive ~41% of revenue in top shooters, and **currency-rebate passes show ~72% repeat purchase** (VoxBooster aggregation of Sensor Tower/Newzoo: https://voxbooster.com/blog/battle-pass-statistics-2026; treat as third-party aggregation). Google/King practitioner data: premium-pass buyers play more sessions and return more; passes are effective first-time-buyer converters; persistent bonuses encourage repeat purchase (https://engineering.zooz.com/googleplaydev/how-battle-passes-can-boost-engagement-and-monetization-in-your-game-d296dee6ddf8).
- **Battle-pass caveats:** content treadmill is real; passes amplify retention but do not create it; some 2026 commentary notes pass fatigue in AAA (https://www.gameorbitpro.com/article/battle-passes-peaked-monetization-model; https://vectraplay.com/blog/battle-pass-and-subscriptions-explained).
- **Subscriptions:** convert lower than passes but retain strongly; price $1.99–9.99/mo typical in mobile; trials work (https://engineering.zooz.com/write-a-catalyst/how-to-monetize-a-mobile-game-2026-guide-6fa097d9c677).
- **Genre conversion reference (unofficial):** roleplay experiences ~1–2%, social/hangout ~0.5–1% conversion, with 80–150 Robux ARPPU typical (https://calculatorkaro.com/?p=2125/ — third-party estimate, use only as a prior).
- **Creator economy context:** RDC 2026: median DevEx creator ~$1,500/year vs top-10 average $65.7M — a power law; scale is the driver (https://www.islandatlas.net/tr/news/2026-09-19-roblox-median-creator-payout-epic-uefn).

**Strength of evidence:** platform economics = strong (primary filings/docs). Battle-pass conversion numbers = moderate (aggregated third-party; directionally consistent across multiple independent summaries). Genre conversion = weak (unofficial; used only as priors). All local game facts = verified from source.

---

## 8. Prioritization matrix

Scale: Revenue impact / Retention impact / Confidence / Effort / Time-to-result / Risk. H=high, M=medium, L=low.

| # | Idea | Rev | Ret | Conf | Effort | Time | Risk | Bucket |
|---|---|---|---|---|---|---|---|---|
| O-01 | Season Pass | H | H | M | M | 4–6 wk | M (content treadmill) | High-priority investment |
| O-02 | Barista Club subscription | H | H | M | M | 4–6 wk | M (billing) | High-priority investment |
| O-05 | Seasonal/limited cosmetics | M | H | H | L | 2–3 wk | L | High-priority investment |
| O-03 | Starter bundle / FTB offer | M | M | H | L | 1–2 wk | L | Quick win |
| O-04 | Wire dead surfaces | M | M | H | L-M | 1–3 wk | L | Quick win |
| O-07 | BB pack bonuses/bundles | M | L | H | L | 1 wk | L | Quick win |
| O-20 | Price localization/labels/tip jar | L-M | L | H | L | 1 wk | L | Quick win |
| O-08 | Points sink | M | M | M | L-M | 2–3 wk | L (Jack decision) | Quick win |
| O-09 | Duplicate trade-ups | M | H | M | M | 3–4 wk | L | High-priority investment |
| O-10 | Happy Hour / second visit | L-M | H | M | L-M | 2–3 wk | L | High-priority (retention) |
| O-11 | Referral ladder / win-back | M | M | M | M | 3–4 wk | L | High-priority investment |
| O-12 | Loadout presets | L-M | M | M | M | 3–4 wk | L | Strategic |
| O-13 | VIP expansion | M | M | M | L-M | 2–3 wk | L | High-priority investment |
| O-14 | Paid event variants | M | M | L | M | 3–4 wk | M | Experimental |
| O-15 | Collection bonuses | L-M | M | H | L | 1–2 wk | L | Quick win |
| O-06 | Persistent ownership goods | H (whale) | M | M | M-H (art) | 4–8 wk | M | Strategic |
| O-18 | Limiteds/trading | H (long) | H | L | H | 6+ mo | H | Strategic (defer) |
| O-19 | Private islands | M-H | M | L | H | 2+ mo | H | Strategic (defer) |
| O-16/17 | Creator codes / ads | M | L | L | M/H | later | H | Defer |

**Foundational first:** instrumentation (§11) and the O-04 wiring, because they de-risk everything else. **Highest-value combinations:** O-01 + O-05 (season pass whose track is fed by seasonal cosmetics) and O-02 + O-07 (subscription for convenience + pack bonuses for spenders) — these four cover the four payer segments with minimal overlap.

---

## 9. Financial scenarios

**Model:** Monthly bookings ≈ DAU × payer conversion × ARPPU. Net creator cash ≈ bookings × 70% (marketplace fee) × DevEx rate (standard $0.0038/R$; 18+ eligible spend $0.0054/R$). Platform 30% fee + DevEx conversion makes net **≈26–27% of bookings** at standard rates, higher if 18+ US spend is material.

**Illustrative inputs (explicitly hypothetical — no game data exists yet):**

| Scenario | DAU | CCU implied (~DAU/6-8) | Payer conversion | ARPPU/mo | Monthly bookings | Monthly net (std) |
|---|---|---|---|---|---|---|
| Low | 2,000 | ~250–330 | 1.0% | R$ 150 (~$5) | R$ 3,000 (~$300) | ~$80 |
| Base | 5,000 | ~600–800 | 1.5% | R$ 250 (~$8) | R$ 18,750 (~$600) | ~$160 |
| High | 20,000 | ~2,500–3,300 | 3.0% | R$ 400 (~$13) | R$ 240,000 (~$7,700) | ~$2,000 |

Assumptions: 1 R$ ≈ $0.0035–0.01 depending on purchase size (Robux bundle-dependent); RP-genre conversion 1–3%; ARPPU from RP genre references + platform ARPPU. **These are planning illustrations, not forecasts.** The actual unknowns to replace them: real DAU, conversion, ARPPU, and pack price points (live Marketplace metadata only — not in the repo).

Sensitivity: a **season pass converting 5% of DAU at 399 R$** adds ≈ DAU×0.05×399 R$/month gross; at 5,000 DAU that is ~99,750 R$/month (~$3,000 gross, ~$800 net standard) — the single largest modeled lever, consistent with battle-pass literature. A starter bundle converting 3% of new DAU once adds a one-time bump only.

Gross vs net: subtract Roblox's 30% marketplace fee and DevEx conversion; no server/ops costs are borne by the developer (Roblox hosts), so the main costs are content production and Jack's time. Refunds are handled by Roblox; the game's own receipt logic minimizes non-delivery risk.

---

## 10. Recommended roadmap

**Phase 0 — Instrument & clean (1–2 weeks, before anything else)**
- Ship §11 instrumentation (purchase funnel, offer views, economy events already partly exist via `AnalyticsEvents`).
- Fix the 20 failing tests in the uncommitted tree (not monetization, but they block safe iteration).
- Decide with Jack: Celebrity revive-vs-retire, Points sink direction, first pack pricing/bonus.

**Phase 1 — Quick wins (2–4 weeks)**
- O-03 Starter bundle; O-07 pack bonuses/bundles; O-20 labels/tip jar; O-15 collection bonuses; O-04 wiring (Robux capsule products once IDs exist).

**Phase 2 — High-priority investments (1–2 months)**
- O-01 Season Pass (build the track with O-05 seasonal cosmetics as its content).
- O-02 Barista Club subscription (or defer one month if pass launch consumes capacity).
- O-09 trade-ups; O-10 Happy Hour; O-11 referral ladder; O-13 VIP expansion.

**Phase 3 — Strategic (2–6 months, only after Phase 2 data)**
- O-06 persistent ownership goods; O-12 loadouts; O-14 paid events.
- Evaluate O-18 Limiteds/trading and O-19 private islands against actual DAU/whale behavior.

**Defer:** O-16 creator codes, O-17 ads (scale/platform dependent).

---

## 11. Instrumentation plan

Existing: `AnalyticsEvents` (funnel, economy, custom via Roblox `AnalyticsService`), leaderboard batching, `RobuxDonated`/`ProcessedReceipts` profile records, purchase history DataStore.

**Add (server, all via `AnalyticsEvents`):**
- `ShopView(tab)`, `OfferImpression(offerId)`, `OfferClick(offerId)`, `PurchasePromptShown(productId|passId)`, `PurchaseSucceeded(productId|passId, robux)` (fire from `ProcessReceipt` post-grant hooks), `FirstPurchase(userId)`.
- Economy: already logs every BB flow with reason — add reasons for any new sinks/sources and keep `LEADERBOARD_EXCLUDED_REASONS` updated for non-play credits.
- Retention: `SeasonPassXpGained`, `SeasonTierClaimed`, `SubscriptionRenewed/Cancelled`, `TradeUpUsed`, `LimitedItemPurchased`, `ReferralSent/Converted`, `HappyHourJoined`.
- Funnel: extend `FirstSession` steps (Join → First Serve → First Pay → First Capsule → First Pass) — `AnalyticsEvents:Funnel` already dedupes per player per step.

**Dashboards (Roblox Creator Hub + AnalyticsService):** conversion rate, ARPPU, ARPDAU, payer count, D1/D7/D30, pass conversion, pass completion, BB sources/sinks by reason, refunds (Roblox), spend concentration (top 5% share).

**A/B testing:** use `UIFlags`-style feature flags + server-side bucketing by `UserId % N` (no new framework). Test: starter bundle offer timing, pack bonus amounts, pass price points (where Roblox permits), seasonal rotation length.

**Guardrails:** D1/D7/D30 retention (non-payers must not degrade), session length, refunds/complaints, spend concentration (avoid >50% from top 1%), free-track completion rate, and the existing "no failure screens / continued play" invariants.

---

## 12. Final recommendations

1. **Instrument, then build the Season Pass (O-01) as the flagship.** It is the highest-leverage, best-evidenced recurring product, it fits the existing quest/XP plumbing, and its content can be fed by the seasonal cosmetics system (O-05).
2. **Convert first-time buyers on day one (O-03 + O-07).** Cheap, evidence-backed, and they feed the same receipt pipeline.
3. **Wire the dead surfaces (O-04) before adding new ones.** A dead Celebrity tab and stubbed Robux capsules are demand left on the table.
4. **Add a convenience subscription (O-02) second**, once the pass proves the audience will pay recurring; keep its perks in existing families so nothing stacks.
5. **Protect the earn/spend slope.** All price/reward changes stay PENDING JACK; do not squeeze serve pay; add veteran sinks (O-09, O-05) instead of nerfing sources.
6. **Keep purchases transparent and click-only** — the existing `BobaBucksShortfall`/`PassUpsell` patterns are exactly right; extend rather than replace them.
7. **Defer trading, ads, and private islands** until DAU/whale data justify them.

The game's commercial ceiling is not set by its store (which is already well-structured) but by **recurrence and urgency** — a season pass plus seasonal limiteds plus a subscription closes that gap with the least risk to the experience the game already delivers well.
