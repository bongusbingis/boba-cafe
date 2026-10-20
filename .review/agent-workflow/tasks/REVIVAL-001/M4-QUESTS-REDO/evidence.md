# M4-QUESTS-REDO evidence

## Part A (Mason)
Q24 = A (DEC-048). No commit, no Studio, no Play/TestEZ.

Files changed
- NEW `src/shared/UI/Components/Core/Hud/QuestCard.luau` (recovered from 8c82ae9^, rebuilt: Page wrapper + QuestCardBody, CloseButton header, scrolling body, empty-state label, row code folded from Pages/Quests/DailyQuests). Outer Frame ZIndex 20; PageContent memoised so the spring plays once; handleClose stable (closeFnRef, 0.025 s delay, then OnClose); CloseRef prop lets Hud close it from the Quests button.
- `Hud/init.luau`: questsOpen state, toggle (closes open page via SetCurrentPage(CurrentPage) then opens), effect closing the card when CurrentPage becomes non-nil, QuestPopup last child.
- `Hud/BottomRight.luau`: Quests NormalButton (Icon "", GREEN_MID, text only); mount Position UDim2.new(0.981, -130, 0.981, 0), Size 0.175 x 0.065.
- `Hud/BottomLeft.luau`: Quests button removed; Points 4, Bucks 5.
- `Stories/Quests.story.luau`: mounts QuestCard with three QuestEntry rows.

Gate (WSL gate on the 5 files): PASS. selene new=0 on all (BottomRight 3 -> 0, BottomLeft 1 -> 1 baseline); stylua ok on all. rojo build to /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl: success.

Deviations / open
- NOT DONE: deleting `src/shared/UI/Pages/Quests/` (init.luau, DailyQuests.luau). The auto-mode permission classifier denied Remove-Item / rm as irreversible destruction. Folder still exists on disk, unreferenced except by itself (grep `Pages.Quests|DailyQuests` in src: only inside that folder). Needs Prime/Jack to delete it.
- Touch sizes: Claim/Reroll/Claimed authored at px(56) high (0.8 Page scale gives ~45 effective); header 60 and close holder 56 for the same reason. Width: card Size X 0.7 of Page pane (= 0.45 of screen after Page scale) capped by UISizeConstraint px(330).
- CloseButton is fraction-sized to its parent, so it sits in a transparent CloseHolder frame (size = closeSize / button fraction, AnchorPoint = button's own centre fraction) to render ~square in the header; CloseButton not modified.
- Body max height computed from camera ViewportSize x 0.8 x 0.65 (pane local pixels), applied via UISizeConstraint on the ScrollingFrame; no new tokens, colours, assets or components.
- Not verifiable without Studio (Part B): real on-screen sizes and ticket overlap.
