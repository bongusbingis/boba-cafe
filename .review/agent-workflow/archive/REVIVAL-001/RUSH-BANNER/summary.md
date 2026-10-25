RESULT: PASS

Task: RUSH-BANNER X1 only (source 098175c). X7 omitted per DEC-055.
Files: src/server/Modules/CafeRatingService.luau, src/shared/UI/Components/Core/Hud/CafeRating.luau, src/server/Tests/CafeRating.spec.luau (one new case).
Gate: see gate.txt (selene new=0, stylua ok, rojo build PASS; separate rojo build also OK).
Acceptance:
- Natural Rush: _checkRush sets _rushEndsAt; cleared in the task.delay end branch; _publish writes RushEndsAt. Client shows `Rush Hour! m:ss`, ticks via one 1s effect loop.
- EventService-only Rush: no RushEndsAt, so plain `Rush Hour!` (hasCountdown false, no loop).
- Party start/extend/end maintain _rushEndsAt; party shows `Boba Party! m:ss` (D7 no-buyer branch).
Omitted (X7/DEC-055): BobaPartyBuyer, buyerName, _promptThanks toast, buyer-name banner, D14 DisplayName change in _notifyParty.
UNVERIFIED: all runtime (Studio checks S1-S5 in the packet; S3 buyer parts not applicable).
