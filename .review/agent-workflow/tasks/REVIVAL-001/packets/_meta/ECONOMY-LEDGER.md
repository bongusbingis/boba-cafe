# ECONOMY-LEDGER (PROPOSED values)

| packet | value | PROPOSED number | rationale |
|---|---|---|---|
| PATIENCE-RAMP | CustomerConfig.PATIENCE_RAMP_FIRST_SHIFT | 3 | C6: first session shift that trims NPC patience |
| PATIENCE-RAMP | CustomerConfig.PATIENCE_RAMP_TRIM_PER_SHIFT | 0.05 | C6: shift 3 = x0.95, shift 4 = x0.90 |
| PATIENCE-RAMP | CustomerConfig.PATIENCE_RAMP_MAX_TRIM | 0.10 | C6: floor x0.90 keeps the Fast window (>=50%) reachable; inside the 5-10% brief |
| BIG-B1-P2-POOL | CustomerConfig.ORDER_POOL Taro Boba Weight (L2) | 10 | ~1 in 12 orders at L2 (8.3%); classics keep 83.3% |
| BIG-B1-P2-POOL | CustomerConfig.ORDER_POOL Strawberry Boba Weight (L2) | 10 | same as Taro; base pay unchanged (Boba Teas 3), avg pay/item 2.40 -> 2.50 from mix only |
| BIG-B1-P2-POOL ext | CustomerConfig.ORDER_POOL Espresso Weight (L7) | 8 | BIG-B1 D5; 6.25% at L7 (total 128), classics 78.1%; pays existing Coffees 2. APPROVED (Jack, 2026-10-20) |
| BIG-B1-P2-POOL ext | CustomerConfig.ORDER_POOL Mango Boba Weight (L8) | 8 | BIG-B1 D5; 5.9% at L8+ (total 136), classics 73.5%; pays existing Boba Teas 3; avg pay/item 2.47 from mix only. APPROVED (Jack, 2026-10-20) |
| BIG-B2 | CafeUpgradeConfig Potted Plants Lv1/2/3 | 150 / 300 / 500 BB | DEC-058 Opus-set, Jack to tune; cosmetic, per-server |
| BIG-B2 | CafeUpgradeConfig Fairy Lights Lv1/2 | 250 / 500 BB | DEC-058 Opus-set, Jack to tune; cosmetic, per-server |
| BIG-B2 | CafeUpgradeConfig Tip Jar Lv1/2/3 | 300 / 600 / 1000 BB | DEC-058 Opus-set, Jack to tune; per-server |
| BIG-B2 | CafeUpgradeConfig Jukebox Lv1/2 | 400 / 800 BB | DEC-058 Opus-set, Jack to tune; cosmetic, per-server. Full set 4,800 BB per server |
| BIG-B2 | CafeUpgradeConfig.TIP_JAR_CHANCE / TIP_JAR_EXTRA | 10% / 20% / 30% chance of +1 BB per NPC serve | DEC-058 Opus-set, Jack to tune; ~+3-9% NPC pay for the whole server |
