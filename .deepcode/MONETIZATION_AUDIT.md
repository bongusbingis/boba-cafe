# Monetization Audit — Payer Conversion 0.97%

Generated 2026-10-24 by the Primary Reasoning Agent. Read-only audit + proposals; no code changed.
Evidence: code reads of `Shop/init.luau`, `Shop/Featured.luau`, `Shop/Season.luau`, `Shop/Currency.luau`, `ProcessReceipt.server.luau`, `StarterBundleReceipts.luau`, `ProductIds.luau`, `PassUpsell.luau`, `LevelUpCelebration.luau`, `PaycheckCard.luau`, `ShiftService.luau`.

## 1. What already exists (the good news)

- **The money path is fully wired.** `ProcessReceipt` maps live product IDs for Skip Hatch, donations, **BobaBucks packs** (5 tiers), **Season Pass ("Brew Bonus", 299 R$)** , **Starter Bundle (~99 R$)** , Boba Party, Rush Hour, BobaBuddy Cleaner/Stocker/Costume. All grants are idempotent (`PurchaseId` dedupe) and `PurchaseGranted` only after a confirmed save.
- **The Shop is a top-bar tab with 8 pages:** Featured (ROSE-tinted landing), Season ("Brew Bonus"), Products (BB packs), Passes, Pets, Nametags, Particles, Group Benefit. `DialogService:OpenShop(player, "Currency")` remaps to the Products tab (`Shop/init.luau`), `"Capsules"` remaps to Pets.
- **Featured.luau fetches live prices** (`MarketplaceService:GetProductInfo` — DEC-026 compliant) for Headless, Pumpkin Launcher, Boba Party, Season Pass, Starter Bundle, and BobaBuddy; the Starter Bundle hero hides itself once `StarterBundleClaimed`.
- **Pass upsells already exist and obey Jack's hard rules** (`PassUpsell.luau`): click-only purchase prompts, owners never see an offer, live prices, no auto-open. They appear:
  - `LevelUpCelebration`: every 3rd level (**3, 6, 9…**),
  - `PaycheckCard`: from the **2nd** completed shift, then every 3rd (**2, 5, 8…**).

## 2. Why payer conversion is 0.97% (the gaps)

1. **No monetization surface in the first ~10 minutes.** A new player's first shift ends at level 2. The level-up upsell starts at level 3, and the paycheck upsell starts at shift 2 — both beyond the 7.8-minute churn cliff. The highest-intent moment (first shift + level 2) shows **zero** purchase offers.
2. **The only post-shift shop nudge is dead for new players.** `ShiftService:_capsuleNudge` toasts only when the balance ≥ 75 BB (cheapest capsule). A first shift pays ~25 BB, so it never fires. (Fix specced in `.deepcode/REVENUE_NUDGE_SPEC.md`.)
3. **Shop discovery is passive.** The Shop tab exists but nothing ever pushes a first-time visitor there; the free **Group Benefit (Ant Pet)** is buried as the last tab (LayoutOrder 7) and only appears in a rotating hint string.
4. **Starter Bundle has no "moment".** It's a perfect first-purchase (99 R$, 300 BB + 2 capsules) but only exists as a Featured hero card — no post-shift or post-onboarding reference.

## 3. Proposals (low-risk, high-impact; no price/odds changes)

### P1 — First-shift Shop nudge with Starter Bundle copy (already specced)
- **What:** after the first shift, a `ButtonPrompt` dialog: "Shift complete! You earned X BB — pet capsules start at 75 BB. Starter Bundle gets you 300 BB + 2 capsules to start!" with **View Shop / Later**; View Shop → `DialogService:OpenShop(player, "Currency")` (lands on Products).
- **Files:** `ShiftService.luau` (new `_postShiftShopNudge`), per `.deepcode/REVENUE_NUDGE_SPEC.md`.
- **Why:** converts the dead nudge into the first guaranteed Shop visit; the copy plants the Starter Bundle (Featured) and capsule goal.
- **Risk:** low. Click-only, session-once, no new UI.

### P2 — First level-up upsell at Level 2 instead of Level 3 (PENDING JACK cadence)
- **What:** change the level-up cap so the XP-pass upsell first appears at **level 2** (the first level-up every new player hits), then keeps the every-3rd cadence: 2, 5, 8… One-line change in `PassUpsell.ShouldShowOnLevelUp` (`src/shared/UI/Utility/PassUpsell.luau:101-107`): replace the `level < LEVELUP_EVERY` guard with a first-level constant (e.g. `LEVELUP_FIRST = 2`) and `(level - LEVELUP_FIRST) % LEVELUP_EVERY == 0`.
- **Why:** puts a purchase offer at the exact moment of the first level-up celebration (~minute 5) instead of level 3 (~minute 15+, past the churn cliff).
- **Risk:** low technically. **PENDING JACK** because upsell cadence is a monetization pacing decision.

### P3 — Free Ant Pet callout after onboarding (non-paywall Shop entry)
- **What:** after `OnboardingCompleted` (3rd serve), a one-time `ButtonPrompt`: "Free reward: join our group in the Shop to claim a free Ant Pet!" with **View Shop / Later**; View Shop → `DialogService:OpenShop(player, "Group Benefit")`.
- **Where:** `CustomerService:_onServeTriggered` (the same `pcall` analytics block that fires step 5; spawn/defer the dialog; session-once flag like `_shopNudged`).
- **Why:** a free claim drives the first Shop visit + a group join (retention), and the Group Benefit tab sits next to Featured where the Starter Bundle and Season Pass live. Converts Shop into a habit without paywall pressure.
- **Risk:** low. Reuses the exact ButtonPrompt + OpenShop machinery; no price change.

## 4. Expected impact

| Metric | Now | Target (P1+P3 ship) |
| --- | --- | --- |
| New-player Shop visits (first 15 min) | ~0 forced | ≥1 per player |
| Payer conversion | 0.97% | 2%+ (P2 adds upside) |
| Group joins | n/a | lift (Ant Pet) |

## 5. Boundaries (non-negotiable)

- No price, odds, reward, or product-ID changes — all Jack-approved data stays as-is (a "first-time buyer discount" is explicitly out of scope; we surface, we do not discount).
- Purchase prompts open **only** from a player's click (`PassUpsell` hard rules apply to any new upsell).
- Prices are always live `MarketplaceService` metadata; never hardcoded (DEC-026).
- All new dialogs use existing tokens/components (ButtonPrompt + Styles) per DEC-013.
