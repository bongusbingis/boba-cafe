VERDICT: PASS

# M3-REM-C Sentry review (E23 Team Combo)
Scope: uncommitted diff (CustomerService/init.luau, Rules.luau, RealOrderService.luau) plus new TeamComboConfig.luau and TeamCombo.spec.luau. Static read-only review (DEC-019). No P1/P2. Four P3.

## Findings

### P3-1 Real-order serves feed the chain with no throttle (alt-account farming)
- RealOrderService.luau:~279-283 (`RecordTeamServe(grade or "Close")`). Self-serve is correctly excluded (returns at the top of `_onOrderPickedUp`, before any pay or record), and `#specs == 0` returns first. But every non-self pickup counts, even when the E5 repeat-pair throttle (PayMultiplier falls back to 1 after 3 per 10 min) says the pair is farming.
- Scenario: a player with an alt (or a friend) cycles cheap real orders; each counts toward the 10-chain, so two accounts can trigger and refresh a server-wide +10% window repeatedly. Gain is 10% of everyone's pay, and the farmer's own cost is low. This needs two accounts and the real-order pipeline, so it is weak, and is not a new exploit class (the pair already earns 2x for 3 orders).
- Fix (optional, no pay change): count a real serve only while `multiplier > 1` (the pair is not throttled), or only for a distinct customer within the last N serves. Jack decision: accept or throttle.

### P3-2 Chain/state survives an empty server
- init.luau `_teamChain` is never cleared (packet step 5 asked for teardown alongside `_combo`; the state is server-global so there is no per-player hook). `_teamComboUntil` expires by clock so it is safe; a stale chain of 1-9 carries into the next session's first players. Harmless. Fix if wanted: reset `_teamChain` in PlayerRemoving when `#Players:GetPlayers() <= 1`.

### P3-3 Walkout reset counts every PatienceOut, including NPCs nobody was assigned
- init.luau:`_onCustomerLeft`. Matches C1 ("only a walkout resets", not holder-specific). With big servers and a line of waiting NPCs, walkouts will be common and the combo will be rarer. That is design-consistent; flagging for Jack's playtest tuning only.

### P3-4 Coverage
- TeamCombo.spec tests only the pure helpers and config; the 60 s window, refresh and timer are untested (disclosed). Fixture and require paths match CustomerService.spec (`ServerScriptService.Server.Modules...`, `ReplicatedStorage.Shared.Configuration...`). `expect(Rules.X(...)).to.equal(n)` takes the first return value, which is fine. Nothing that will obviously fail: TeamComboPay(7,true,0.10) = round(7.7) = 8, (10) = 11, and 10 * 1.1 is 11.000000000000002, which rounds to 11.

## Checks
1. No-yield invariant: HOLDS in both paths. NPC: between the guards (1)-(5) and `Modify`, the only additions are `ApplyTeamCombo`, an os.clock read plus `math.round` with no yield. `RecordTeamServe` runs after Modify, after the already-existing non-yielding calls. It has no yield: NextTeamChain is pure, and `task.delay` and `task.defer` do not yield the caller. `CurrencyService:Modify` is itself async via andThen, so it does not yield. Real order: `pcall(Knit.GetService, "CustomerService")` is a table lookup (post-KnitStart), done after the entry-time GetTipBonus yield and after history Record, with nothing yielding before Modify. The M3-REM-B entry-yield placement is untouched.
2. Rules: 10 consecutive serves, NPC and real, either grade, count (NextTeamChain). Only `RecordTeamServe(nil)` from PatienceOut resets (served or despawned leaves do not). x1.10 is applied after Rush Hour (init.luau 788-790), and also on real-order pay, which has no Rush Hour (disclosed). Refresh: a new chain overwrites the deadline to now+60. Announcement is via DialogService:Notify to all players, same shape as `CafeRatingService:_notifyAll`; no remote, no HUD. Values 10/0.10/60 match DEC-036 and DEC-028 E23. Note: the serve that completes the chain is not itself boosted (documented; consistent).
3. Farming. A rescue or re-trigger cannot count twice: the NPC leaves on serve and guard (3) blocks the second trigger (the B-era yield race is closed). Rapid fake serves are impossible: a serve needs a real matching tool, destroyed on use, and a live NPC at the counter. Self-serve does not count. Solo player: pacing target is slots(1)+line(1) = 2 NPCs, spawn gap 3 s, so serve rate is bound by crafting time (~4-6/min); a 10-chain takes about 2 minutes and yields a 60 s window, roughly 1/3 uptime of +10%, so about +3% overall. A solo player cannot sustain it, and the 9 BB/min anchor is not materially affected. Multi-barista servers can sustain +10% permanently (>=10 serves/min); this is the approved design. Only the alt-account real-order path (P3-1) is cheap.
4. Timer: deadline captured per trigger; an older task.delay returns early if `_teamComboUntil ~= deadline`, so refreshes do not produce an early "over" or double announcements; one live timer owns the end. Stacked timers are bounded by one per chain completion (>= 10 serves apart), each ends within 60 s. IsTeamComboActive is a pure clock compare, so pay stays correct even if a timer is late. Shutdown: pending delays are harmless. State is server-global, not per player.
5. Pay math: NPC order base -> variant -> Rush x2 -> Combo -> tip extra (TakeTipExtra on the post-combo pay) added, `result.Tip` = extra, paid once; the real path likewise (extra to AddTip). The Tips line matches the extra paid. Modify reasons unchanged ("Gameplay" for NPC, none for real), so the M4-FIXES leaderboard feed is untouched. Rounding: combo rounds once; the real-path pay is only rounded while a combo is active (pre-existing fractional behaviour otherwise; P3-4 note of M3-REM-B applies).
6. Specs: sound.

## Needs Jack
- P3-1: accept alt-account real-order chain farming, or throttle by pair multiplier.
- P3-3: playtest tuning, if combos prove too rare.
