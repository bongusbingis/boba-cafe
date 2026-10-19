RESULT: PASS (implemented, not run in Studio)
Changed: CustomerConfig.luau (VARIANTS), CustomerService/{Rules,Npc,init}.luau, Tests/CustomerService.spec.luau (variant money cases). Multi-item NPC orders: Npc.Orders/Specs, FindServeTools(npc.Specs), Payout over all items, ticket.Items added (Spec = first item).
Gate: PASS on all 5 files (selene new=0, stylua ok, rojo build ok).
Studio for Jack: L10 profile, wait for Karen (look from NPCStorage.Karen, Confused on Close, stomps out); L6 VIP gold bubble; L5 two-item orders.
Questions: scripted NPCs drop the variant but keep Karen's look; client ticket UI (OrderController) must read ticket.Items for multi-item; VIP 10% still a placeholder.
