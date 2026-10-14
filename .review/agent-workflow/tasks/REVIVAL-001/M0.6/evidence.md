# REVIVAL-001-M0.6 evidence (Mason)

Task: REVIVAL-001-M0.6, DEC-006 Skip Hatch only purchasable while a pet is hatching.

## Source state
HEAD 92f61447ecd8ebb898fefb841261fabeb46b51cd, working tree already dirty (earlier M0 work). diff.patch is the delta vs the
pre-edit copies of the two files (saved in scratchpad), not vs HEAD (git diff vs HEAD for these files is 468 lines of prior work).
shasum after edit:
- 16c5076d0e777c93eb293cd1f5da684ef7e6f2a2  src/server/Scripts/ProcessReceipt.server.luau
- 9bde35c187311090cdd5b75518ff49285065c730  src/shared/UI/Components/Core/Hud/BottomLeft.luau

## What changed and why
- ProcessReceipt.server.luau: Skip Hatch handler returns (false, "no hatch pending") when playerData.HatchingPet is nil/false;
  previously it returned true (and so PurchaseGranted + recorded receipt) with nothing applied. handleReceipt already treats a
  non-true result as finish(NotProcessedYet) BEFORE recordReceipt/saveThenDecide, so no receipt record, no history write, no skip
  credit. Warn now includes the reason. Doc comment on ProductActionMap updated. Other products/IDs/prices untouched.
- BottomLeft.luau: PromptProductPurchase now guarded on a pending hatch (capsuleHatching truthy and ~= false); CapsuleButton is
  only rendered while hatching (explicit ~= false so a false state cannot render it).
- No spec: receipt logic lives in a .server script (handleReceipt is local, not a module), so it cannot be required from TestEZ
  without a refactor outside the scope.

## Gates
- selene (rokit 0.31.0 binary, rokit shim not resolvable from repo): baseline 0 errors / 1 warning; after 0 errors / 1 warning, identical output.
- stylua 2.5.2 --check: baseline clean, after clean (rc 0).
- rojo build default.project.json -o m06.rbxl: OK.
- TestEZ in Studio: UNVERIFIED (Studio leased elsewhere).
