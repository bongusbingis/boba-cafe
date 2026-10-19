RESULT: PASS
CHANGED: src/server/Modules/KitchenService/Actions/ToolAttributeCheck.luau (new); src/shared/Kitchen/Recipes.luau (Sugar/Ice attribute gates, Coffee 7->4, Ice 5->3 TUNING Q14); src/server/Tests/OrderSpec.spec.luau (renamed sugar-before-ice case, new B1 ice-before-sugar case); src/server/Tests/KitchenAttributes.spec.luau (harness runs ToolAttributeCheck). OrderSpec.luau untouched: sugar-before-ice already returns ice current with no problem. Loader needs no edit: ActionRegistry requires all children dynamically.
GATE: PASS all 4 files (selene new=0, stylua=ok, rojo build ok); no new warnings. Sink gate #Cup|!Milk left as-is (Q22).
STUDIO (UNVERIFIED for M1.6, no Studio step run): Gauge coffee — Cup Small, Coffee Machine Regular, serve, expect Perfect; Gauge sugar-then-ice — add Sugar, then Ice Machine, serve, expect same finished tool (Iced, Sugar); Gauge ice-then-sugar — Ice Machine then Sugar, serve, expect same finished tool.
QUESTIONS: none.
