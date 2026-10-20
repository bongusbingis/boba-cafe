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

## Part B (Lens)
Studio 61656dd1 ("jacks project"), Edit mode only, no Play/TestEZ, no saves, no script edits.

Source freshness: djb2 (CR stripped) Studio == repo: Hud/init 3444690112, QuestCard 227123852, BottomRight 478932062, BottomLeft 3757154664. Pages now: Menu, Shop, Inventory, Ordering, MobileOrder, Recipes (Pages/Quests absent).

Mounts: temporary StarterGui._LensPreview (ResetOnSpawn=false, ZIndexBehavior=Sibling, IgnoreGuiInset=true), ReactRoblox root rendering the real Hud (CurrentPage=nil, SetCurrentPage=noop). "Open" runs render Hud plus QuestCard (edit-mode PREVIEW_QUESTS: 3 rows = mid-progress with 20 BB reroll, Completed with Claim, Claimed) as a full-size sibling frame, standing in for QuestPopup (Hud's own toggle cannot be clicked in edit mode). Springs do not advance in edit mode; Page UIScale read 0.8 (settled).
Viewports: desktop = real Studio viewport 1173 x 864 (1280 x 832 not settable). Phone-size = the Hud mounted in an 844 x 390 Frame (red outline, preview only) inside that viewport; camera ViewportSize cannot be set, so usePx (camera-based) stays at the 1173 x 864 scale: phone-size card/button px are NOT true phone px. 390 x 844 portrait not captured (viewport not settable). Not mountable: two order tickets and ShiftCard (need live controller data), so TicketStack is empty in all captures; overlap computed from source anchors.

Captures (captures/): a-closed-bottomright-{desktop,phone844x390}.jpg, b-quests-open-{desktop,phone844x390}.jpg, c-bottomleft-{desktop,phone844x390}.jpg (c is the same frame as a: stack reads Clock Out, Recipe Book, Daily, Points, Bucks; Quests absent from the left).

Measurements
- Desktop card: 257.6 x ~315 px at (457.7, 274), centred; Body ScrollingFrame 257.6 x 267.2; UISizeConstraint card MaxSize X 322. Header 33 px (title), CloseButton 44.0 x 43.9.
- Claim / Reroll (20 BB) / Claimed button: 80.8 x 44 effective px (>= 44 met, exactly 44; Page scale 0.8 applied). Same 44 in the 844 x 390 run.
- Quests button: desktop x 813-1023, y ~817-850 (0.69-0.87 width, bottom edge ~0.98); 844 x 390 run x ~548-700, y ~359-385.
- TicketStack overlap (computed, bottom anchor y 0.92, grows up): desktop stack bottom 795 vs button top ~817 = ~22 px clear; 844 x 390 stack bottom 359 vs button top ~359-364 = ~0-5 px clear (touching at best; verify with real tickets on a device). Horizontal ranges overlap, so vertical clearance is the only separation.
- Thumb zones (left stick 0-0.3 w, bottom 45%; jump 0.75-1.0 w, bottom 40%): card x 0.35-0.65 of width (844 run), y 38-352 of 390; clear of the left zone and of the jump zone horizontally; card bottom 352 (of 390) is inside the bottom-40% band but at x 0.35-0.65, so it does not touch either zone. Quests button (844 run) spans x 0.65-0.83: overlaps the jump zone's left part (0.75-0.83) in the bottom band; desktop 0.69-0.87 same overlap in principle. Not clear of the jump zone by the packet's zone definition; real jump button hit area needs a device emulator check (Jack).
- Dim/overlay: none. New visuals: none (pop-up card on Page; CloseButton in card header = existing component, new combination).
- Serve path: no server/serve/payout code touched.

Cleanup: _LensPreview destroyed; StarterGui children 1, ReplicatedStorage children 7 (as before). Nothing saved.

## Q26 follow-up
Jack chose Q26=B: move the Quests button left of the mobile jump zone. BottomRight.luau JUMP_BUTTON_CLEARANCE 130 -> 196 (mount X offset -130 -> -196 px); comment updated.
Computed span, 844 x 390 frame: right edge = 0.981*844 - 196 = 632.0 px (0.749 width, <= 0.75 jump zone start at 633); width 0.175*844 = 147.7 px, so left edge = 484.3 px (0.574 width, clear of the 0-0.3 stick zone). Minimum offset is -195; 196 gives ~1 px margin.
Gate: see run result below.
