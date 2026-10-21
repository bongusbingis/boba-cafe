---
id: BIG-B1-P4-MASTERY
title: B1 phase 4 - drink mastery stars (STUB; full packet written after release)
priority: P2
role: Mason
release_gate: after
depends_on: [BIG-B1-P3-RECIPEBOOK, BIG-B5, ENGAGE-FRIEND-INVITE]
status: READY-PENDING-CONFIRM
source_commit: 098175c
---
Source excerpt: P7: Drink mastery stars: serving N Perfects of a drink gives it bronze, silver and gold stars in the Recipe Book. Files: profile field, Recipe Book. Effort: M. Risk: Low.
Decisions made: D1 Scope is the ORDER_POOL Keys enabled at the time (today Taro Boba, Strawberry Boba and the three classics). D2 Design per BIG-B1 D12-D14: new profile field `Mastery = { [Key]: number }` (add only), NPC Perfect serves counted by a new MasteryService off `CustomerResolved`, tiers 10/30/75 PROPOSED, GOLD stars on Recipe Book headers, no BobaBucks or XP.
Open items: LEASE: Prime appends this packet to the ProfileTemplate.luau and CustomerService/init.luau chains; full packet (strings, signatures, specs, Studio checks) is written after release.
## Summary
- Post-release stub; mastery design is fixed in BIG-B1 section 4 D12-D14 and section 7.
