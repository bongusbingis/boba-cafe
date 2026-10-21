# BIG-B5 Regulars

Commit 48610d4 on worktree-agent-adf5ff5bd640b759a (merge pending). Opus-designed under Jack's 2026-10-21 latitude; numbers in RegularsConfig marked "DEC-058 Opus-set, Jack to tune".

- 12 regulars.
- Spawning:
  - 12% of non-VIP/Karen customers.
  - At most one regular every 60 s, server-wide.
  - 60% lean toward regulars a clocked-in barista hasn't met yet.
- Ordering: at Take Order they order their favourite. If the barista's level is too low for it, they get a "Surprise me" order from the pool instead.
- Greeting: after the first serve they greet the barista by display name.
- Stamps: each serve stamps the barista who took the order.
- Completion reward: all 12 stamped pays 2,500 BB plus the title "Cafe Favourite", once.
- Looks are placeholders (skin colour and scale), applied through the `Npc.new` look argument. Clothing, face and hair are TODO slots for Jack. If a look fails to apply, the NPC gets the normal random look.
- New profile field: `Regulars = {Visits={}, RewardClaimed=false}`.
- Menu has a new Regulars tab. Side-tab padding went from 0.015 to 0.008 so 9 tabs fit.

## Studio checks
1. Play with workspace attribute `RunTests=true`; Regulars.spec passes.
2. Set `SPAWN_CHANCE=1`, `MIN_GAP_SECONDS=0` in RegularsConfig (revert after).
3. Clock in; bubble "<Name>: Hi, can I order?", prompt shows their name.
4. Take Order: introduction; notepad shows the favourite.
5. Serve: toast "New regular: <Name>! Stamp 1/12"; card fills under Menu > Regulars.
6. Serve the same regular again: greets you by name; card shows 2 visits.
7. Nine Menu tabs fit on desktop and phone.
8. Set 11 `Regulars.Visits` via command bar, serve the 12th: +2,500 BB, title, "Reward claimed".
9. Fill the TODO looks in RegularsConfig later.
