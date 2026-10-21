# RUSH-BANNER-X7 evidence (Mason lane)

RESULT: PASS
Task: X7 Boba Party spotlight (packet RUSH-BANNER, inert until BOBA_PARTY_PRODUCT_ID exists).
Source commit: 098175c. X1 verified present: commit 9931bc9 in history; `_rushEndsAt`/`RushEndsAt`
publish, countdown banner text, and 1s tick loop all present in the working tree and untouched.

## Changed (write scope only, no commit)
- `src/server/Modules/CafeRatingService.luau`: `_partyBuyer` field (D2); `_publish` writes
  `BobaPartyBuyer` (D2); `buyerName` helper DisplayName-or-Name-or-nil (D5); start/extend/end set
  buyer + countdown per D4; `_promptThanks` toast to non-buyers on start+extension (D6);
  `_notifyParty` texts use `buyerName` with `Someone` fallback, wording unchanged (D14).
- `src/shared/UI/Components/Core/Hud/CafeRating.luau`: `buyer` state + `BobaPartyBuyer` signal (D7);
  `shortName` 8-char cut (D8); banner rules rush+party+buyer / party-no-buyer / rush (D7/D11);
  X1 tick loop deps `{ rush, endsAt }` unchanged (D10); Banner Size 0.7 and green color unchanged (D9).
- `src/server/Tests/CafeRating.spec.luau`: 4 new `it` cases only (DisplayName spotlight + publish,
  Name fallback, extension re-spotlight + nil-extend keeps buyer, nil-publish clears attribute).
  beforeEach/afterEach untouched.
- HARD-STOP 4 held: `BOBA_PARTY_PRODUCT_ID` untouched (still nil), no product ID/price set anywhere.
  EventService/EventConfig/ProcessReceipt/RatingConfig untouched. No sound added.
  `src/server/Scripts/ActivityScript.server.luau` never read, staged, or modified.

## Gate
- `gate` on all three files: PASS, selene new=0, stylua=ok (see `gate.txt`).
- `rojo build default.project.json -o /tmp/RUSH-BANNER-X7.rbxl`: built, 1381892 bytes.

## Acceptance proof (code, not runtime — Studio checks unrun per DEC-019)
- S1/S2 (X1): preserved verbatim from X1; gate + build green, no X1 lines altered.
- S3: start path sets `_partyBuyer`/`RushEndsAt`, publishes both, toasts non-buyers; extension
  recomputes countdown, re-spotlights extender, toasts again (CafeRatingService.luau:109-153).
- S4: party end sets `_partyBuyer`/`_rushEndsAt` nil before final `_publish` (line 168-172).
- S5: both attributes are server-time numbers from one `_publish`; client diffs vs server clock.

## UNVERIFIED
- All in-Studio behavior S1-S5 (banner text, toasts, countdown tick, two-client skew); TestEZ not
  run (DEC-019). New spec cases written but not executed.
- Toast exclusion relies on buyer Player identity (`player ~= buyer`); receipt-path buyer object
  shape confirmed only by code read of ProcessReceipt (read-only).
- utf8 8-char cut edge cases (exact-8, multibyte) covered by code path, not executed.

## RISKS
- X7 inert until product exists (by design); no monetization values touched.
- Pre-existing: RushHour double writer (CafeRatingService vs EventService) handled defensively
  per D11; separate fix packet owns it.

## NEXT
- Prime batches S1-S5 into the milestone Studio run; Jack picks the deferred wide-banner layout
  (open item) before X7 ships.
