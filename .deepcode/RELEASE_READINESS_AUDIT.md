# Release Readiness Audit — Final Batch (Go/No-Go)

Generated 2026-10-24 by the Primary Reasoning Agent. Read-only. Verdict: **GO** (no blockers).
Files reviewed in their post-Gemini state: `AnalyticsEvents.luau`, `CustomerService/init.luau`, `ShiftService.luau`, `LevelUpCelebration.luau`, `PaycheckCard.luau`, `Hud/init.luau`.

## 1. Analytics Relay — SAFE

`AnalyticsEvents.Client:Custom(player, name, value, extra)` (lines 168–184):
- Knit injects the calling `Player` as argument 1, so `player` is always valid when invoked via the remote.
- Client fires with no event args → `name`/`value`/`extra` all nil → `eventName` stays nil → `return`. **Silent drop, no crash.**
- The `elseif typeof(value) == "string"` branch is defensive and correct (covers direct calls with an explicit player first).
- `pcall(self.Server:Custom(...))` never yields the client: `Custom` itself defers to `safe` → `task.spawn` + `pcall`. Belt-and-suspenders. ✅

**Hardening item (tomorrow, not a blocker):** `Client:Custom` accepts arbitrary event names at arbitrary frequency. Each call spawns a server task (`safe`) — an exploiter could spam it (telemetry pollution + task churn). It touches **no DataStore** (AnalyticsService only) and cannot crash. Recommend a per-player rate limit (e.g. 20 events/min, drop excess) or a client-sourced event-name allowlist (`PassUpsell*`, `ShopNudge*`, `AntPet*`).

## 2. Serve Path — CLEAN, no new yields

`CustomerService:_onServeTriggered` (lines 1760–1939):
- Yield inventory: `GetTipBonus` (before guards, allowed by contract) → guards → `FindServeTools` (sync) → grade/`closeText` (sync) → `GetPourTip` `pcall` (sync) → seating clone `pcall` (sync) → **tool destroy (1845–1847)** → payout (sync) → `CurrencyService:Modify` (non-yielding) → `_readServedCount` (yields, but **pre-existing** at the same position before this batch, and it runs *after* tools are destroyed and money is paid — no double-consume/double-pay risk).
- New telemetry (`ServedItem_*`, `TutorialOrderServed_*`) sits inside the existing `pcall` analytics block (1875–1892); `AnalyticsEvents.Custom` defers via `safe`. No yield added.
- Ant Pet prompt (1894–1923): `_groupNudged` set synchronously, then the dialog runs in `task.spawn` + `pcall` — the serve path never waits on it. `_groupNudged` is cleared in `PlayerRemoving` (line 2832). ✅

## 3. Shift End Path — CORRECT

`ShiftService:_endShift` (247–399):
- Nudge call site (375–383) is spawned + `pcall`-guarded and gates on `summary.First == true`; shifts 2+ get the old `_capsuleNudge`. `_postShiftShopNudge` itself **also** early-returns on `if not summary or not summary.First then return end` (456–459) — double gate confirmed. ✅
- `ShopNudgeShown` (477–479) and `ShopNudgeClicked` (495–497) are `pcall`-guarded; `_shopNudged` cleared in `PlayerRemoving` (642). ✅
- "Next shift" toast (384–398): spawned + `pcall` + `task.delay`, with a `player.Parent ~= nil` guard. ✅
- `Shift2Started`/`Shift2Completed` (326–330) are inside the existing analytics `pcall`, using `state.Completed` correctly (0 → shift 2 starting; 1 → shift 2 done). ✅
- Minor copy nit (not a blocker): "Check the Shop  pet capsules" is missing a comma/em-dash in `_postShiftShopNudge` Text.

## 4. UI Memory — CLEAN

- `LevelUpCelebration` (275–285) and `PaycheckCard` (181–191): `shownPassIdRef` fires `PassUpsellShown` only when the ref differs from the current `offerPassId` → once per pass per card mount. No re-render spam, no leak (component-local refs). ✅
- `Hud/init.luau` quests auto-open (61–83): `conn:Disconnect()` is in the effect cleanup (80–82). `questsFirstShiftOpened` ref blocks repeats. The spawned wait thread is not cancelled on unmount and doesn't re-check `LocalPlayer` before `setQuestsOpen(true)` — worst case is a benign `setState`-after-unmount warning on shutdown (the HUD is persistent). **Nit, not a blocker.**

## 5. Analytics Security — see §1 hardening item

No crash or data-bloat vector; only rate/allowlist hardening recommended.

## VERDICT: GO

No crash risks, no double-pays, no soft-locks, no blocking yields introduced by the final batch. Safe to leave live overnight.

### Watch tomorrow morning
- **FTUE:** `FirstItemTaken` → `FirstServe` → `OnboardingCompleted` (Brownie-first flow), and `TutorialOrderServed_1/_2/_3` — specifically the `_2 → _3` drop (the Boba order).
- **Retention:** `Shift2Started` → `Shift2Completed` (are players attempting the 10-serve shift?), `FirstShiftCompleted` timing, D1 retention vs. the 2.03% baseline.
- **Monetization:** `ShopNudgeShown → ShopNudgeClicked` ratio, `PassUpsellShown → PassUpsellClicked → PassPurchased`, `AntPetPromptShown → AntPetPromptClicked` + group joins, and `StarterBundlePurchased` if the bonus event shipped.
- **Stability:** server memory trend (map work landed?), client FPS field reports after the Rigger pass, and any `[AnalyticsEvents] AnalyticsService call failed` warnings (rate-limit indicator).

### Hand to tomorrow
1. Rate-limit/allowlist `AnalyticsEvents.Client:Custom`.
2. Cancel the quests auto-open thread on unmount (or guard `LocalPlayer.Parent` before `setQuestsOpen`).
3. Fix the "Shop  pet" copy comma.
4. (Latent, pre-existing) consider moving the `_readServedCount` yield in `_onServeTriggered` before the payout block during the next serve-path refactor.
