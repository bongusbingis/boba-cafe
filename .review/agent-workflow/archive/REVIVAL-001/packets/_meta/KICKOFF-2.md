You are Prime (Claude Opus) for REVIVAL-001 in C:/Users/jackc/Desktop/boba-cafe, branch uhweifh. Commits local, never push. Never reset/clean. Never touch/commit src/server/Scripts/ActivityScript.server.luau. HARD DEADLINE Friday 2026-10-23 (DEC-055). Today 2026-10-20. DELEGATE: keep your own context small (<100k); do not read packets or code yourself, dispatch Sonnet/Opus agents and read only their <=12-line reports.

READ ONLY: _meta/STATUS.md ("Session 2026-10-20 part 2" at the bottom), decisions.md DEC-053..DEC-057.

DONE (all committed locally, gated, NOT run in Studio): GAMEPLAY-SERVE-QUEST-YIELD 10c20a5 (Sentry PASS-WITH-P3), GAMEPLAY-TOASTS a74764d, NOTIF-HINTS bef4c1c, GAMEPLAY-QUEST-NUDGES d23eedd, REALORDER-SHIFT bf3bdc6 (Sentry PASS-WITH-P3), HUD-BOTTOMLEFT d92f8ba, HUD-LEVELBAR 3c78c22, RUSH-BANNER X1 9931bc9, GAMEPLAY-MOBILE-TICKET 8339432, TICKET-RECIPE-LINK 676b2dc, SERVE-FEEDBACK fae5a1f, SERVE-PAYPOPUP S3 54c8294, NPC-REACTIONS 9fa5757, QUESTS-PING 9a5179e, CLIENT-PATIENCE C1/C3 1a4d892, GAMEPLAY-PROGRESS-CALLOUTS 47fa5c1, SHIFT-END 5edfc9b, ONBOARD-FIRSTRUN 2fd821a, ONBOARD-NICK 0d1cb8f, SOUNDS 7be73eb, DEC-057 ticket move c17aac3.
IN FLIGHT at clear time: B1 builder (agent a7b6de18398cc2842): BIG-B1-P2-POOL then P3-RECIPEBOOK (Taro/Strawberry L2). Check `git log` for BIG-B1 commits; if absent/incomplete, re-dispatch a Sonnet builder.

TODO in order:
1. B1 extension (Jack said yes to Espresso L7 + Mango L8): Opus agent amends BIG-B1-P2/P3 packets to add them (verified in source per P2 report), then Sonnet builder. Hot Cocoa (L3) and Strawberry Tapioca (L4) stay out until Jack confirms place-file items.
2. One Sonnet agent: commit the untracked evidence files (tasks/REVIVAL-001/*/summary.md, packets/*, _meta/*, decisions.md) by explicit path in ONE docs commit. Do not stylua DEC-001 drift files.
3. Fix leftovers: AppDialogs.luau had pre-existing StyLua drift (leave). Quests card has no opener (DEC-057, deferred; BottomRight.luau unused).
4. Sonnet agent writes the short "Ship Plan" Artifact (ship set, asset requests, ONE batched Studio checklist assembled from each packet's "Studio checks" bullets, Questions for Jack) and updates STATUS.md. No big final artifact.
5. Whole-branch review: one Opus agent runs a code-review over commits 098175c..HEAD focused on cross-packet interactions (CustomerService/init.luau toast ordering, SmallNotification queue, ShiftCard 6-row cap, ONBOARD-NICK/NicknamePending/ShiftCardOpen, LevelBar mount vs BottomLeft).
6. Studio checklist to Jack Wed night/Thu; fixes Thu/Fri; ship Friday.

PENDING FROM JACK: Hot Cocoa L3 and Strawberry Tapioca L4 place-file checks (kitchen Mug/Hot Chocolate Powder/Mug Tool; Strawberry Tapioca station); sounds under SoundService.SFX.UI (Serve, StepDone, Rush, LevelUp new; Pop1, Success verify). Open UI notes: CafeRating overlaps ticket column on phone (accepted for now); XP label ~9px; Quests opener later.
DEFERRED (stubs exist): REALORDER-HEARTS, STREAK-REMINDER, SHIFT-STARS-SOUND, PATIENCE-RAMP, T5, T8, S9, X7, B2, B4, B5, B6, B7 (station minigames, stub only), H6, Q6, X10; quest rollover race P3 (QuestService 83-103).
ANTIGRAVITY TEST: agy (allowed via PowerShell(agy:*)) reproduced NOTIF-HINTS exactly (3 min); verdict viable for small mechanical packets only; DEC-035 keeps real work on Claude unless Jack approves.
Rate limit: stop dispatching, update STATUS.md, tell Jack.

UPDATE (after the lines above): B1 DONE: BIG-B1-P2-POOL a6bc551, BIG-B1-P3-RECIPEBOOK ee9a515 (Taro/Strawberry L2). So TODO 1 is only the Espresso L7 + Mango L8 extension. FINDING: TICKET-RECIPE-LINK 676b2dc built only the T4 "Fast bonus!" cue; the tappable drink name -> Recipe Book focus was NOT wired, so Recipes/init calls Content.build(nil, level). Decide with Jack or dispatch a small Sonnet lane to wire it (packet TICKET-RECIPE-LINK, link half).
