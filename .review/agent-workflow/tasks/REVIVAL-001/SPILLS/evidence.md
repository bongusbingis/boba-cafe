RESULT: PASS
Files changed: src/server/Modules/SpillService/init.luau only (Spill.luau holds no storage path — it reads Service("SpillService").Storage.{Tools.Mop,MopBucket,SprayBottle,DishTowel,Sparkles,Spills[Boba]}, all present in v4 CleanlinessStorage; no Tests spec names the old path).
Gate: PASS — stylua ok, selene new=0, rojo build ok (RUNBOOK step 3, changed file only).
Gauge steps for M1.6 (UNVERIFIED, DEC-019): wait for a spill to appear, clean it with the mop, confirm the SpillsCleaned stat goes up.
Docs hit for Q-DOCS-M1 (not edited): docs/SYSTEMS.md:157 names ReplicatedStorage.SharedStorage.Spills.
Question for Jack: src/client/Modules/SpillController.lua:257,260,111,201 still point at SharedStorage.Spills — outside this packet's write scope; needs a follow-up lane/packet to repoint to CleanlinessStorage (also checks Animations/BoardInterface children).
