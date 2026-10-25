RESULT: PASS
CHANGED: OrderController, KitchenGuidance (comment), KitchenController (Serve target = ticket.NpcModel; ServePrompt visibility loop, 0.2s Heartbeat), OrderTicket (label row for NPC tickets, patience fraction from PatienceEnd/PatienceTotal fed to RecipeCard's existing bar, GOLD_MID = Close/yellow), KitchenGuidance.spec (M1.4e ticket case).
GATE: PASS (no new selene findings, stylua ok, rojo build ok).
UNVERIFIED (M1.6): two-client prompt visibility (Serve/Rescue), patience bar colours/updates, Serve highlight on NPC. Studio/Lens NOT RUN.
STYLE.md s10: tokens only (GREEN_DEEP, GOLD_MID via RecipeCard); no new tokens. Bar reuses RecipeCard's patience bar (M1.5b), not a second bar. Prompt Rescue fraction 0.3 is a literal per packet.
