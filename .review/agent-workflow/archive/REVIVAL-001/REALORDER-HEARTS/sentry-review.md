# Sentry review — REALORDER-HEARTS (money path)

Verdict: PASS. Diff matches packet D1–D7 exactly; no economy, profile, or secret touch.

- (1) Serve-path no-yield: nothing added between pickup guards and `CurrencyService:Modify` (line 313–315); new `_askHearts` call is after payout + SHIFT block, `task.defer` + `pcall` (lines 337–343). Pre-existing yields (tip-bonus pcall, task.spawn AdvanceQuest) untouched.
- (2) Non-currency: only `IncrementStat` on `HeartsReceived`/`HeartsCount`; no BB/Points/XP, no ProfileTemplate/ledger change. Tests only assert `HeartsToast` strings.
- (3) No farm/spam: call gated on `customer ~= nil and CountsForTeamChain(multiplier)` (throttled 4th+ pair serves excluded); `_rating[customer]` one-shot guard retained; `_askHearts` builds a promise, no yield.
- (4) Toast isolated: `DialogService:Notify` for the barista toast is inside its own `pcall`, after both stat increments, same table shape as existing Real-customer toast; prompt Title/Text untouched (D7); buttons stay 1–5, no icon (D6).
- (5) No secret/ID material: only `DisplayName` with `[<>&]` strip + 20-char cap; `barista.UserId` usage pre-existing.

Unverified (no Studio/TestEZ per orders): S1–S6 runtime behavior; Selene/StyLua/rojo gates (Prime-batched).
Risk: negligible — async post-payout prompt + pcall'd toast; customer-leave path captured name up front (D4).
Next: Prime runs gate + batches S1–S6 Studio checks, then sign-off.
