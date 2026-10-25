# M4-UI-APPROVAL evidence (Lens)
Studio: jacks project (placeId 89999123284040), Edit mode only. Staleness: all 5 modules byte-identical to repo (CR-normalized length + hash match): DailyRewardsDialog, QuestCard, BottomLeft, DailyRewardConfig, QuestConfig.
Mount note: preview ScreenGui needed ZIndexBehavior=Sibling (Global hides content). Springs do not advance in edit mode: dialog panel is frozen at UIScale 0.8 (smaller than in play).
Screenshots (this folder):
- a-dialog-day3-canclaim.jpg: BB 30/45/60/60/90/120/180; Day 4 Regular and Day 7 Rare capsule icons+labels; Day 1-2 Claimed, Day 3 Claim!, Claim Day 3 Reward button.
- b-dialog-day3-vip.jpg: 2x VIP pills; 60/90/120/120/180/240/360; capsules present.
- c-dialog-claimed.jpg: Day 1-3 Claimed, disabled "Next in 11:59:59", countdown subtitle.
- d-questcard-expanded.jpg: 3 quests (1/5, 10/10 Claim, 4/4 Claimed); reroll button reads "20 BB". Collapsed state NOT captured (needs a click; input tools forbidden).
- e-daily-button-bottomleft.jpg: Clock Out, Recipe Book, Daily (gold, bucks icon), counters. No claim-available indicator exists.
## QuestCard defects (real code, not preview artifacts)
1. Claim/Reroll button (QuestActionButton) has no Position/AnchorPoint, so it sits at x=0 on top of the progress bar (only "Claimed" label is right-anchored). Hides the "1 / 5" and "10 / 10" labels.
2. Header: Pane defaults BackgroundTransparency to 1 when Native lacks it, so the green fill is missing and the OFFWHITE "Daily Quests" title is invisible on the white card.
Non-STYLE.md visuals: not verified against STYLE.md in depth; QuestCard values (230 px width, 16 px pill/bar) come from code.
Cleanup: _LensPreview destroyed; StarterGui/ReplicatedStorage child counts unchanged; nothing saved.

## Re-capture after QUESTCARD-FIX (d2-questcard-fixed.jpg)
Studio QuestCard source matched repo (len 14733, hash match). Studio's require cache still held the old module, so a temporary clone of QuestCard was parented under _LensPreview and required (destroyed with the gui); no change to the place.
Result: header is green with readable "Daily Quests" title and toggle. Reroll "20 BB" and Claim buttons are right-aligned; no overlap with progress bars or "1 / 5", "10 / 10" labels. Collapsed state not capturable via prop (isExpanded is internal state); skipped.
Cleanup: _LensPreview destroyed; StarterGui=1, ReplicatedStorage=7 children (unchanged); nothing saved.
