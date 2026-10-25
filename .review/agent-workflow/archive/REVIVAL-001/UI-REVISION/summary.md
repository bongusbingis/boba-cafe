# UI-REVISION summary and handoff (2026-10-21)

Authority: Jack, "full explicit authority to make revisions/remediations (under STYLE.md) without my permission if it's justified." Every change uses only STYLE.md tokens, components and patterns. Each area lists why it changed.

## Style rules from the original UI and STYLE.md
1. Fonts: Fredoka for everything. Denk One only for secondary stat labels.
2. Palette:
   - GREEN: titles, banners, confirm buttons.
   - GREEN_LIGHT: dialog body text and borders.
   - GREEN_DEEP: names and values.
   - GREEN_DIM: strokes.
   - ROSE family: guide and sell. CORAL/RED: dismiss. GRAY: tracks and hints.
   - New shades only as a Lerp of a token (stroke = fill lerped 0.15 to black).
3. Gold is for money and rank only (+N BB, balance, level fill, stars). Never buttons, combo or quests.
4. Text colour:
   - White on coloured fills.
   - OFFWHITE for HUD chrome.
   - GREEN_LIGHT body text on the light 9-slice panel.
   - GREEN titles on page backgrounds; GRAY hints.
5. Text is TextScaled with a UITextSizeConstraint max (18-30) matching a sibling. Fixed TextSize only on the order ticket (13/15).
6. Radii: pill CORNER_FULL, dialog button 0.25, card CORNER_CARD 0.06, NPC bubble CORNER_BUTTON, ticket 6 px.
7. Strokes: dialog button 3 (fill lerp), panel GREEN_DIM 4-5, bubble GREEN 2, ticket GREEN_DIM 1.
8. Titled cards: 9-slice panel 13473433246, GREEN_LIGHT border 13382163077, GREEN Banner ribbon (13369767169/13369762471). Lists: ShopCategory header, ShopItem rows, footer slice.
9. Tab pages: centred title at (0.470149, 0), size 0.94 x 0.09, GREEN. Optional GRAY wrapped hint at y 0.095, height 0.085. Scroller at y 0.112.
10. Layout: scale + AspectRatio + UISizeConstraint for HUD and dialogs. Billboards are pixel-sized and use SizeOffset for placement.
11. Motion: pop-ins use the Page spring {1, 2500, 100} from 0.6 to 1. Buttons use SPRING_STANDARD with the sibling's hover/press pair (PromptButton 1.07 / 0.93). Animate UIScale, not Size.
12. Copy (FEEDBACK-VOICE):
   - Sentence-case status lines, Title Case controls.
   - Numbers first ("+12 BB", "×5"), " · " separator.
   - "!" only on celebrations; buttons name their verb.
13. `LayoutOrder = math.huge` overflows and sorts first. Keep it only as the original top spacer; never use it for something meant to be last.

## Captures
- `captures/` holds the before set (hud-overview, staff-top, staff-titles, npc-bubble) and after-npc-bubble.
- After that, Studio screen_capture timed out for the rest of the session. The other areas were checked by measuring in the running client: AbsoluteSize, TextFits, TextBounds.
- Tweens and springs don't run in that context, so motion is unverified. The Play session predates the merges and these commits.

## Areas done (selene, stylua --check and rojo build pass on each)
- **NPC bubble (96e5de3).**
  - Change: item name plus a softer flavour line, text-size limits, centred outlined syrup chip, bordered speech card, GOLD_DEEP stroke on VIP.
  - Why: text size swung from huge to tiny, the chip was invisible on Milk Tea, and the speech line was an unbordered slab.
- **Staff tab (30138b0).**
  - Change: rank card with gold XP bar, 6 stats, title list with no coin glyph. Adds an optional `PriceGlyph` to ShopItem/ShopCategory; the default is unchanged.
  - Why: a coin glyph showed before "Earned", plus an unlabelled bar and 10 duplicate cards.
- **Pour meter (15b3f05, 68d21d9).**
  - Change: OrderQueue chrome with a "Pour Timing" banner, GRAY/GREEN/GOLD track, input-aware hint, PromptButton-style "Pour" button (35 px), pop in/out, CORAL "Messy pour".
  - Why: the meter stretched on phones, had a "TAP!" slab, two fromRGB literals and a 26 px button.
- **Regulars (b5c5984).** Standard title and a wrapping hint. Why: the title was a left-aligned outlier and the status line shrank to nothing.
- **Order ticket (c50ecfc).** Ready footer moved to the bottom with rounded corners. Why: its `math.huge` LayoutOrder sorted it above the header.
- **Rush banner (012c298).** Bar shows the time left and "×2 pay". Why: it read a stale "0%".
- **Pay popup (9d3928b).** The order card hides when the NPC leaves; "+N BB" takes its place, rises and fades. Why: it overlapped the speech line and had no motion.
- **Shift card (62923cb).** Readable text, gold star row, voice copy, pop-in. Why: OFFWHITE body text on the light panel was nearly invisible.
- **Quest card (87faa95).** Button reads "Reroll / 20 BB" in GREEN_LIGHT. Why: a bare "20 BB" read as a reward, and it was gold on a button.
- **Upgrades board (7459b1e).** Banner ribbon title. Why: a flat bar, where every other titled surface uses the ribbon.

## Left alone
- Toasts: render unchanged from the original.
- Nickname prompt: the original dialog plus Skip.
- Titles page, LevelBar/BottomLeft: already match.
- Ticket patience bar, KitchenController input, Ordering/App.luau: the logic fixer was editing these.

## Remaining, in priority order
1. Fresh Play after Rojo sync, then re-capture every area. Check bubble placement, pour pop-in, ShiftCard spring and the Rush bar.
2. Tablet Ordering pages (own orange theme).
3. GamepassBoardController, DonationReceipts and LeaderboardService rows (5 fromRGB literals).
4. RecipeCard and the ticket patience bar.
5. PlayerOverheads fonts.
6. Daily Rewards row copy and colours.

## Known issues
- The bubble title must stay the only direct TextLabel in Card, because RegularsService finds it with FindFirstChildOfClass. The flavour line sits under DetailHolder on purpose.
- Working copies are CRLF, so `stylua --check` reports whole-file diffs. Strip the CRs first; git stores LF.
