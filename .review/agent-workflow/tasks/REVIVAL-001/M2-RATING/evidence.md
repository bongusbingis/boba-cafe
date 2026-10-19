RESULT: PASS
Changed: CafeRatingService.luau, RatingConfig.luau, CafeRating.spec.luau (new); Hud/CafeRating.luau (new), Hud/init.luau (mount); SpillService/init.luau (SpillCleanedSignal); SpillService/Spill.luau (one line: self.CleanedBy = Player, outside write scope, needed for cleaner XP/rating); CustomerService/init.luau (rush helpers, pay x2, no variant while any clocked-in barista is in the scripted first session).
Gate: PASS on all 8 files. BoostMultiplier crash already removed (grep finds nothing); no change made.
Deltas per DEC-021: spill +3, fast +1, walkout -2, drain -0.5 per 5s while spills exist (all PROPOSED); meter frozen during Rush. No "wrong" grade exists, so none built.
Studio (Jack): set START = 99; verify meter top centre, Rush toast/pay, spill XP 5.
