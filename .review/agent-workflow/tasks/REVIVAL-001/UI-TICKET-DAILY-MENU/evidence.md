# UI-TICKET-DAILY-MENU Part A evidence (Mason)

Answers applied: Q27 A, Q28 A, Q29 none, Q30 A, Q31 A (DEC-052). No commit, no Play/TestEZ, no Studio, no server edits.

## Files changed (all under src/shared/UI)
- Components/Core/Hud/init.luau: TicketStack (now `Pane` with `Scale = px.scale(1.6)`, 190 px base width) moved into new `RightColumn` Frame (anchor (1,0), Position (0.99,0.14), AutomaticSize Y, width = ceil(190 * scale), UIListLayout vertical right-aligned, gap 10). ShiftCard is the second child with a fixed size equal to its old clamped size (0.2w x 0.3h, Min 190x160, Max 300x250, from camera viewport).
- Components/Core/Hud/ShiftCard.luau: optional `ColumnSize` prop; in column mode it drops its own anchor/position/aspect ratio and sets LayoutOrder 2. Without the prop behaviour is unchanged. Internals untouched.
- Components/Core/Hud/BottomLeft.luau: Daily button removed; Points 3, Bucks 4. Knit require kept (still used by other calls).
- Components/Dialogs/DailyRewardsBody.luau (NEW): hooks, helpers and `rewardsTab` moved verbatim from `DailyRewardsMenu`; props `{ Status }`; returns the rewards Frame.
- Components/Dialogs/DailyRewardsDialog.luau: `DailyRewardsMenu` = `OpenableMenu` + `c(DailyRewardsBody)`; exported Page wrapper unchanged; story needs no change (same require path).
- Pages/Menu/Daily.luau (NEW): thin wrapper; body fetches its own status on mount.
- Pages/Menu/init.luau: Daily Rewards tab at LayoutOrder 2, others 3-8; Food Menu stays default (first).

Not touched: server files, DailyRewardController, DialogController, OpenableMenu, Page, Styles, OrderTicket, BottomRight, story.

## Step 5 grep
`OpenDailyRewards`: only DailyRewardController (definition and join auto-open). `DailyRewardsDialog`: controller auto-open and story. No other callers.

## Gate
WSL gate on all 7 files: GATE: PASS. Selene new=0 on each (BottomLeft baseline 1, now 1). StyLua ok on 6 files (Hud/init was clean at HEAD, so stylua was run on it); Menu/init.luau has pre-existing drift (HEAD drifted), gated without stylua. `rojo build` inside gate: PASS (output outside repo).

## Deviations / notes for Lens (Part B)
- ShiftCard in column mode uses fixed offset size computed in Hud from `Workspace.CurrentCamera.ViewportSize` (no UIAspectRatio); sizes match packet figures (256x250 at 1280x832, 190x160 at 844x390).
- UIScale inside a UIListLayout/AutomaticSize parent: assumed layout and auto-size use the scaled size. Lens must verify the column height and no overlap.
- Jump-zone overlap risk (Q28 A) is unmeasured; fallback is Q28 B.
- No new colour/radius/font/asset; only ticket size changed.

## Part B (Lens): Studio captures, edit mode only
Freshness: djb2 (CR stripped) of all 7 modules (Hud, BottomLeft, ShiftCard, Menu, Menu/Daily, DailyRewardsBody, DailyRewardsDialog) matches the repo in Studio (Rojo synced). No Play/TestEZ, nothing saved, no script edits.

Mounts: temp `StarterGui._LensPreview` (ResetOnSpawn=false, Sibling, IgnoreGuiInset=true), ReactRoblox root. Edit mode has no controller data, so the real Hud was cloned INTO the preview gui and patched in the clone only: initial state seeded for OrderTicket (slot 1 "Large Taro Milk Tea", slot 2 "Medium Brown Sugar Boba", label-type tickets, no RecipeCard) and ShiftCard (summary seeded); camera/usePx faked in the clone so the phone frame uses true phone scale (844x390, scale 0.75, ticket UIScale 1.2). Desktop = real Studio viewport 1171x864 (scale 0.975, ticket UIScale 1.56; 1280x832 is not settable). Springs do not advance in edit mode; the Menu is wrapped in a static Pane (0.8 size, UIScale 0.8) standing in for Page. Phone zone overlays (thumb 0-0.3 w / bottom 45%, jump 0.75-1.0 w / bottom 40%) are preview-only fills.

### Hud right column (Q28 A)
| viewport | tickets | TicketStack (w x h, y range) | ShiftCard (size, y range) | column bottom |
|---|---|---|---|---|
| desktop 1171x864 | 2 expanded | 296x159, y121-280 | 234x250, y290-540 | 540 |
| desktop | 1 expanded | 296x72, y121-193 | 234x250, y203-453 | 453 |
| phone 844x390 | 2 collapsed | 228x79, y55-134 | 190x160, y144-304 | 304 |
| phone | 2 expanded | 228x122, y55-177 | 190x160, y187-347 | 347 |

- UIScale flows into layout and AutomaticSize (no overlap tickets vs ShiftCard).
- Ticket text: 15 px base = 23.4 px desktop, 18.0 px phone (header and body both 15 base). Header height 28 base = 34 px phone. Legible.
- Phone jump zone (x>=633, y>=234): ShiftCard OVERLAPS it (x646-836; collapsed y144-304 = 70 px inside zone, expanded y187-347 = 113 px). Tickets alone end at y134 (collapsed) / 177 (expanded), clear. Thumbstick zone: clear. ShiftCard is the transient, non-interactive end-of-shift card (Active=false).
- Quests button (x484-632, y361-383 phone): no overlap with column; sits 1 px left of the jump zone. No Quests change needed (Q29).
- CafeRating: clear. TopBar: 10 px x / 4 px y bounding-box overlap on phone only (column x607 vs TopBar right edge x617, y55 vs 59); the TopBar's visible content is clear in the capture.
- Not measurable in edit mode: real slot-1 ticket with RecipeCard (taller; needs KitchenGuidance spec), so worst-case expanded height is larger than shown. Long multi-item labels ("A + B") do not wrap in OrderTicket and overflow at 1.6x (seen in a first test run with a 35-char label).
- Pre-existing, not ours: TopBar clock pill overlaps CafeRating title on the phone frame.

### Bottom-left
Stack without Daily: Clock Out, Recipe Book, Points, Bucks (b-bottomleft-*; same frames as the Hud captures).

### Menu with Daily tab 2 (Q30 A)
Daily tab opens with the DEC-045 A body (7 day rows, Claim Day 1 button, streak line). 8 tabs: DO NOT FIT.
- Desktop: tab panel (SideButtons) y254-676, tabs 59 px pitch; Credits (8th) at y682-721 lies below the panel and the Container clips it (y240-690), so only a sliver shows; 7 tabs visible.
- Phone: panel y115-305, Credits y308-325, clipped; 7 tabs visible.
- Packet rule: STOP and ask (no new scroll pattern). Options for Jack: shrink tab pitch (OpenableMenu change, not allowed to Mason without approval), or merge/move a tab (e.g. Credits into Server Info or Settings), or drop Credits' button.

### New-visual list
Ticket size only (plus the 8th Menu tab, which currently clips).

### Q28 fallback
Fallback B needed: ShiftCard overlaps the phone jump zone under A.

Captures: captures/ (a-hud-tickets-desktop-1/2, a-hud-tickets-phone-2collapsed-shift, a-hud-tickets-phone-2expanded-shift, b-bottomleft-*, c-menu-daily-*, d-menu-tabs-*).

Cleanup: `_LensPreview` and cloned modules destroyed; StarterGui children 1, ReplicatedStorage 7 (unchanged). Nothing saved.

## Fallback B (Mason, DEC-052)
Trigger: Lens Part B measured ShiftCard inside the phone jump zone under Q28 A.

Changes (Hud/init.luau, Hud/ShiftCard.luau only):
- ShiftCard.luau is byte-identical in logic to its pre-53700c3 form (ColumnSize prop and inColumn plumbing removed; `git diff 53700c3^ -- ShiftCard.luau` empty). ShiftCard is a Hud sibling again at anchor (1,0), Position (0.99,0.14), Size (0.2,0.3), AspectRatio 1.2, Min 190x160 / Max 300x250.
- Hud: the ticket column (1.6x, same Frame + TicketStack Pane as Part A) is anchored (1,0) at Position UDim2.new(0.99, -(shiftWidth+10), 0.14, 0), shiftWidth = clamp(0.2*viewportX, 190, 300). Removed the ShiftCard-in-column and shiftSize code. No server edit, no new tokens.

Geometry (shiftWidth is the upper bound of the ShiftCard width; the 1.2 aspect may shrink it, which only widens the gap):
| viewport | scale | ShiftCard x / y | ticket column x / y (2 tickets) |
|---|---|---|---|
| 1171x864 | 0.975, tickets 1.56 | x ~926-1159, y 121-up to 371 (234x<=250) | width 296, x ~620-916, y 121-280 (2 expanded) |
| 844x390 | 0.75, tickets 1.2 | x 646-836, y 55-215 (190x160) | width 228, x ~408-636, y 55-134 collapsed / 55-177 expanded |

Zone checks at 844x390: ShiftCard bottom y215 < jump zone top y234 and thumbstick zone (x<253) is far left: clear. Ticket column right edge x636 exceeds 633 but its bottom (134/177) is above y234: clear (a taller real slot-1 ticket with RecipeCard would need >57 px extra before touching the zone; not measurable in edit mode). Quests button (x484-632, y361-383) far below: clear. Column and ShiftCard are separated by a 10 px gap, no overlap. CafeRating unchanged position. TopBar: the Part B 4 px bbox overlap (y55 vs 59 for x<=617) remains for the column on phone; visible TopBar content was clear in Lens capture. Desktop: no TopBar overlap expected (column top y121).
Not verified in Studio (no Studio/Play per instructions); Lens should recapture.

Gates: stylua --check clean, selene 0 errors/0 warnings on both files. Not committed.
