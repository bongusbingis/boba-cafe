# ECONOMY-LEDGER (PROPOSED values)

| packet | value | PROPOSED number | rationale |
|---|---|---|---|
| PATIENCE-RAMP | CustomerConfig.PATIENCE_RAMP_FIRST_SHIFT | 3 | C6: first session shift that trims NPC patience |
| PATIENCE-RAMP | CustomerConfig.PATIENCE_RAMP_TRIM_PER_SHIFT | 0.05 | C6: shift 3 = x0.95, shift 4 = x0.90 |
| PATIENCE-RAMP | CustomerConfig.PATIENCE_RAMP_MAX_TRIM | 0.10 | C6: floor x0.90 keeps the Fast window (>=50%) reachable; inside the 5-10% brief |
| BIG-B1-P2-POOL | CustomerConfig.ORDER_POOL Taro Boba Weight (L2) | 10 | ~1 in 12 orders at L2 (8.3%); classics keep 83.3% |
| BIG-B1-P2-POOL | CustomerConfig.ORDER_POOL Strawberry Boba Weight (L2) | 10 | same as Taro; base pay unchanged (Boba Teas 3), avg pay/item 2.40 -> 2.50 from mix only |
