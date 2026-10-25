# BIG-B2 Cafe Upgrades

Commit cb26156 on worktree-agent-a6185a985596ee42e (merge pending). Opus-designed under Jack's 2026-10-21 latitude; numbers marked "DEC-058 Opus-set, Jack to tune".

- Code-built Upgrades board. Upgrades last for the current server only and are not saved (no ProfileTemplate change).
  - Potted Plants: 150/300/500 BB.
  - Fairy Lights: 250/500 BB.
  - Tip Jar: 300/600/1000 BB.
  - Jukebox: 400/800 BB.
- Plaque shows the last 8 buyers; every player gets a toast on a purchase.
- Tip Jar: 10/20/30% chance of +1 BB per NPC serve. The roll is on the serve path and does not yield. Everything else is cosmetic.
- Purchases go through ActionPrompt/ButtonPrompt, then the server-side CurrencyService:TrySpendAsync. A per-upgrade lock and a level check prevent double buys. Models use BuiltBy="Opus-B2".

## Studio checks
1. Sync Rojo, Play: `workspace.CafeUpgrades.UpgradeBoard` appears.
2. Move the set via `CafeUpgradeConfig.ORIGIN` (guess (4.6, -9.8, 323.9)); move single pieces via `PLACEMENT`.
3. Give yourself BB, press E at the board.
4. Buy every level; models sit on the floor or counter.
5. Your name is on the plaque; a second client gets the toast.
6. Purchase with too little BB: nothing is spent.
7. Tip Jar bought: some NPC serves pay +1 BB; workspace attribute `CafeTipJarLevel` shows the level.
8. Run TestEZ (RunTests attribute); CafeUpgradeService spec passes.
9. Tune prices and `TIP_JAR_CHANCE` in `CafeUpgradeConfig`.
