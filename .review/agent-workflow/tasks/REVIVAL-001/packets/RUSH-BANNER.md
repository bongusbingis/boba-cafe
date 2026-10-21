---
id: RUSH-BANNER
title: Rush Hour countdown banner (X1) and Boba Party buyer spotlight (X7)
priority: P2
role: Mason
worker_tier: sonnet
release_gate: before   # X1; the X7 portion is release_gate after (inert until BOBA_PARTY_PRODUCT_ID exists)
depends_on: []
status: READY   # X1 ready; X7 portion is inert-until-product (HARD-STOP 4 below)
source_commit: 098175c
read_scope:
  - src/server/Modules/CafeRatingService.luau (_publish, StartOrExtendBobaParty, _checkRush)
  - src/shared/UI/Components/Core/Hud/CafeRating.luau
  - src/shared/Configuration/RatingConfig.luau (read only)
  - src/server/Scripts/ProcessReceipt.server.luau (read only)
  - src/server/Modules/EventService.luau and src/shared/Configuration/EventConfig.luau (read only; second writer of RushHour)
  - src/server/Tests/CafeRating.spec.luau
write_scope:
  - src/server/Modules/CafeRatingService.luau
  - src/shared/UI/Components/Core/Hud/CafeRating.luau
  - src/server/Tests/CafeRating.spec.luau (new cases only; do not edit beforeEach/afterEach)
invariants:
  - DEC-013: reuse the existing `Banner` Title in `CafeRating.luau`; no new component, color or font. Banner size stays (0.7, 0.55) in every state (D9 amended by style review).
  - `RushHour` and `BobaParty` keep their current meaning and writers. This packet only ADDS the attributes `RushEndsAt` and `BobaPartyBuyer` and never changes who writes `RushHour`.
  - `CustomerService:IsRushHour()` reads `RushHour`; it is untouched. No yield is added to any serve path (CafeRatingService runs off the serve path; `_change` runs from the CustomerResolved handler after the payout and gains only field assignments).
  - ProcessReceipt.server.luau is read only; HARD STOP 4: `BOBA_PARTY_PRODUCT_ID` stays nil, no product ID or price is set.
acceptance:
  - During a natural Rush the banner reads `Rush Hour! m:ss` and ticks down each second; at 0 the plain `Rush Hour!` shows until the attribute clears.
  - During a Boba Party with a buyer the banner reads `{Name}'s Party! m:ss`; the other players get one toast `Thank {Name} with an emote!` on start and on each extension.
  - A Rush set only by EventService (no `RushEndsAt`) shows plain `Rush Hour!` with no countdown and no error.
checks:
  - wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/server/Modules/CafeRatingService.luau src/shared/UI/Components/Core/Hud/CafeRating.luau src/server/Tests/CafeRating.spec.luau' (stylua only on files with no DEC-001 drift)
  - rojo build default.project.json -o <path outside the repo>
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/RUSH-BANNER
forbidden: [WORKER-PRIMER 8, editing EventService or EventConfig, editing ProcessReceipt or setting any product ID, changing RatingConfig values, changing what writes RushHour, adding a sound (SOUNDS packet owns CafeRating.luau later), running Play or TestEZ]
---

Rules: see `_meta/WORKER-PRIMER.md`. Idea review text below is verbatim.

## 1. Source excerpt
- X1 (review, HEAD c77e20c): What: Rush countdown: the server publishes RushEndsAt; the banner reads "Rush Hour! 1:24". Why: Urgency, and players stay to the end. Files: CafeRatingService.luau, Hud/CafeRating.luau. Effort: S. Risk: Low. Tag: OBVIOUS.
- X7 (review, HEAD c77e20c): What: Boba Party spotlight: the buyer's name in a top-centre banner during the party (existing Banner) and a thank-you emote prompt. Why: Social spend should feel celebrated; drives repeat purchases. Files: CafeRating.luau banner text. Effort: S. Risk: Low. Tag: JACK (monetization presentation).

## 2. Decisions made
- D1: Time base is server time. The server writes `RushEndsAt = workspace:GetServerTimeNow() + seconds` (same clock as `BobaPartyCooldownEndsAt`); the client computes `math.ceil(RushEndsAt - workspace:GetServerTimeNow())`. Rationale: both clocks agree, no per-second replication.
- D2: `CafeRatingService` keeps `_rushEndsAt` (number or nil) and `_partyBuyer` (string or nil); `_publish` writes `RushEndsAt` and `BobaPartyBuyer` (nil clears the attribute) next to the existing three attributes. Rationale: one publish point, the existing pattern.
- D3: Natural Rush: `_checkRush` sets `self._rushEndsAt = workspace:GetServerTimeNow() + RatingConfig.RUSH_SECONDS` right where it sets `self._rush = true`; the existing `task.delay` callback sets `self._rushEndsAt = nil` in the branch that ends the Rush (after the `_partyActive` early return, before `_publish`). `_change` already publishes after `_checkRush`.
- D4: Boba Party start sets `_rushEndsAt = workspace:GetServerTimeNow() + RatingConfig.BOBA_PARTY_SECONDS` and `_partyBuyer = buyerName(buyer)` before the existing `self:_publish()`. Extension recomputes `_rushEndsAt = workspace:GetServerTimeNow() + (self._partyEndTime - os.clock())`, sets `_partyBuyer` to the extender (latest buyer is spotlighted) when a buyer is given, then calls `self:_publish()`. Party end sets both to nil before its final `_publish`. Rationale: the countdown always matches `_partyEndTime`.
- D5: `buyerName(buyer)` (takes a Player or nil, returns a string or nil) is a local helper: returns `buyer.DisplayName` when it is a non-empty string, else `buyer.Name` when a string, else nil. Test fakes with only `Name` work. Rationale: Roblox filters display names, so it is safe to show.
- D6: Thank-you emote prompt: a new local `CafeRatingService:_promptThanks(buyer, name)` sends `DialogService:Notify(player, { Title = "Boba Party", Description = text, Text = text })` to every player except the buyer, each inside `pcall`, on start and on every extension. Called only when `name ~= nil`. Rationale: no emote system exists in the codebase (`grep -i emote src` finds none), so the prompt is a toast that points players at Roblox's built-in emote menu; no new mechanism.
- D7: Client banner text rules, evaluated in this order: not `rush` gives `Cafe Rating`; `rush` and `BobaParty == true` and a buyer string gives `{shortName}'s Party!` plus ` {clock}` when remaining > 0; `rush` and party with no buyer gives `Boba Party!` plus ` {clock}`; otherwise `Rush Hour!` plus ` {clock}` when remaining > 0. Rationale: always readable, falls back safely.
- D8: `shortName` = the buyer name unchanged when `utf8.len(name) <= 8`, else the first 8 characters (via `utf8.offset(name, 9) - 1`, `string.sub`) followed by `..`. Rationale: keeps the longest text at 24 characters on a 190 px wide card.
- D9 (amended by style review): the banner `Size` stays `UDim2.fromScale(0.7, 0.55)` (existing value) in every state, including Rush and Boba Party. Rationale: at 844x390 the CafeRating frame is 190 x 38 px at x 327-517, y 45-83, and the ticket column (DEC-052 fallback B) starts at x 407, y 55; a 1.21645 banner (231 px, x 306-538) would push further into the ticket column, which draws under CafeRating (same ZIndex 10, CafeRating is the later sibling). `Rush Hour! 1:24` (15 chars) fits the 0.7 banner's label (about 112 x 13 px) at about 12-13 px, same as `Cafe Rating`. The wide banner for the X7 buyer text is an open item.
- D10: Countdown ticking: while `rush` and a valid `endsAt` exist, one effect (deps `{ rush, endsAt }`) runs a `task.spawn` loop `task.wait(1)` then `setTick(function(n) return n + 1 end)`, stopped by a flag in the cleanup. `remaining` is recomputed on every render from the server clock. No loop runs when the countdown is not valid. Rationale: updates each second with one cheap state change.
- D11: Safe handling of the RushHour double writer (see section 5): the countdown shows only when `RushHour == true` AND `RushEndsAt` is a number AND `RushEndsAt - GetServerTimeNow() > 0`; anything else shows plain `Rush Hour!`. `RushEndsAt` is written only by CafeRatingService and only for its own Rush or Party. EventService stays the writer it already is; this packet does not touch it.
- D13 (FEEDBACK-VOICE 5): the banner keeps its existing `Color = Styles.GREEN`; there is no event colour token, so nothing changes and no gold is used (gold is money and rank only). The Rush start sound is SOUNDS D7 (`Rush` cue on the RushHour rising edge); this packet adds none.
- D14 (FEEDBACK-VOICE 1): people are named by DisplayName. `_notifyParty` replaces `buyer.Name` with `buyerName(buyer)` (falls back to `buyer.Name`, then to `"Someone"`); the rest of its text is unchanged. The banner cut (D8) applies to banners only; the thanks toast uses the full DisplayName.
- D12: X7 is inert until `BOBA_PARTY_PRODUCT_ID` exists: `StartOrExtendBobaParty` is only reached from `ProcessReceipt`'s `ProductActionMap`, which is only populated when that constant is non-nil. No code here sets it.

## 3. Exact strings
- Banner: `Cafe Rating`, `Rush Hour!`, `Rush Hour! 1:24`, `Boba Party!`, `Boba Party! 9:41`, `{shortName}'s Party!`, `{shortName}'s Party! 9:41`. Clock format: `string.format("%d:%02d", math.floor(s / 60), s % 60)`.
- Toast to non-buyers: `Thank {DisplayName} with an emote!`. Existing `_notifyParty` texts keep their wording; only the name source changes (D14).

## 4. Exact numbers
- Name cap 8 characters (`MAX_NAME_CHARS = 8`); tick 1 second; banner width 0.7 in all states (D9 amended); `RUSH_SECONDS` 120 and `BOBA_PARTY_SECONDS` 600 are read from RatingConfig, never copied. No economy values, no ledger rows.

## 5. Signatures, attributes, the double-writer note
- New workspace attributes: `RushEndsAt` (number, server time) and `BobaPartyBuyer` (string). Existing: `RushHour`, `BobaParty`, `CafeRating`, `BobaPartyCooldownEndsAt`.
- Fields: `_rushEndsAt = nil :: number?`, `_partyBuyer = nil :: string?` in `Knit.CreateService`.
- Client: `Hud/CafeRating.luau` adds state `endsAt`, `party`, `buyer`, `tick`; `refresh` also reads `RushEndsAt`, `BobaParty`, `BobaPartyBuyer`; connect `GetAttributeChangedSignal` for the three new names next to the existing ones (disconnect all in cleanup).
- Double writer (verified in code at 098175c; no note exists in decisions.md or SYSTEMS.md, so this is a code finding, not a recorded fact): `EventService:StartEvent("RushHour")` sets `workspace.RushHour = true` for `EVENT_DURATION_SECONDS` (600) and `_endEvent` sets it false; `CafeRatingService:_publish` writes `RushHour = self._rush` on every rating change, and `EventService` also writes false at startup when the attribute is nil. Consequences: an event Rush has no `RushEndsAt` (plain banner, correct); a rating publish can overwrite an event's `true` with false, and an event end can clear a natural Rush's `true`. Both are pre-existing and OUT of this packet. Handling: banner is defensive per D11, and `RushEndsAt` is cleared with the Rush it belongs to so it can never describe an event. Not changed: EventService, `_publish` semantics. Unverified in Studio: whether the overwrite actually happens with a hosted event; Prime decides if a separate fix packet (EventService lease) is wanted.

## 6. UI spec
- Anchor and frame unchanged (`Position (0.5, 0.115)`, `Size (0.2, 0.08)`, `AspectRatio 5`, min 190x38, max 300x60). `Title` Banner: `Color Styles.GREEN`, `Position (0.5, 0.3)`, Size per D9, text per D7; TextScaled is built into Banner. Meter track and Percent label unchanged. Hidden when clocked out (existing). Phone 844x390 (style review, computed): banner 133 px wide, label about 112 x 13 px; X1 strings (`Rush Hour! m:ss`, `Boba Party! m:ss`) render at about 12-13 px. The X7 string `Abcdefgh..'s Party! 9:41` (24 chars) would shrink to about 8-9 px in the 0.7 banner; X7 is deferred (DEC-055) and its width is an open item. Pre-existing overlap (not caused by this packet): CafeRating's frame (x 327-517, y 45-83) overlaps the ticket column (x 407-636 from y 55) and the TopBar bbox (y < 60); see Open items.
- No spring or animation added.

## 7. Studio checks (batched)
- S1: Raise the rating to 100 (or run `EventService`-free test): banner reads `Rush Hour! 2:00` and counts down once per second; at the end it returns to `Cafe Rating`.
- S2: Set `workspace:SetAttribute("RushHour", true)` by hand with no `RushEndsAt`: banner reads plain `Rush Hour!`, no errors.
- S3: Call `StartOrExtendBobaParty` from the command bar with a real player as buyer (no purchase): banner reads `{Name}'s Party! 10:00`; a second player gets one toast `Thank {Name} with an emote!`; the buyer does not; a second call extends the clock by 10:00 and toasts again.
- S4: Let the party end (or lower `BOBA_PARTY_SECONDS` locally and revert): banner returns to `Cafe Rating`, `BobaPartyBuyer` and `RushEndsAt` are nil.
- S5: Two clients show the same remaining time within one second.

## 8. Asset prerequisites
- None. Product `BOBA_PARTY_PRODUCT_ID` does not exist yet (HARD STOP 4).

## 9. Open items:
- HARD-STOP 4: What Developer Product ID should `BOBA_PARTY_PRODUCT_ID` in ProcessReceipt.server.luau use (a number, or "later")? The X7 portion stays inert until then.
- HARD-STOP 4: Should the Boba Party product price stay as Creator Hub set it (yes or no)? Agents set no price.
- PENDING JACK (style review, layout; not blocking X1): at 844x390 the CafeRating meter (x 327-517, y 45-83) overlaps the left 110 px of the upper-right ticket column (x 407-636, from y 55) whenever a ticket shows, and CafeRating draws on top. This predates this packet (DEC-052 fallback B; UI-TICKET-DAILY-MENU evidence measured TopBar, ShiftCard and the zones, not CafeRating). Options: (a) accept; (b) move the ticket column top below CafeRating (the original fallback B text said top at 0.22); (c) move CafeRating. Needs a Lens capture and Jack's pick; no agent moves either element.
- PENDING JACK (X7, deferred): the buyer banner `{name}'s Party! m:ss` needs a wider Banner (1.21645, the ShiftCard/ButtonPrompt constant) to read at phone size, which widens the clash above. Decide together with the item above before X7 ships.

## Summary
- Server publishes `RushEndsAt` (server time) for natural Rush and Boba Party, plus `BobaPartyBuyer`; both cleared with the event.
- Banner shows `Rush Hour! m:ss`, ticking each second via one effect loop; party shows `{Name}'s Party! m:ss` (name cut at 8 characters).
- Non-buyers get one `Thank {Name} with an emote!` toast on party start and each extension (no emote system exists; plain toast).
- RushHour double writer (CafeRatingService and EventService) handled defensively on the client; EventService untouched, fix is a separate decision.
- X7 inert until BOBA_PARTY_PRODUCT_ID exists (HARD-STOP 4); no IDs or prices set.
