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
