RESULT: PASS (not Studio-verified)
Changed: OrderController.luau (Tickets list max 2, TicketsChanged), Hud/OrderTicket.luau (slot/stacked props), Hud/init.luau (TicketStack, gap 10), PlayerOverheads.client.luau (LevelTitle line)
Gate: rojo build PASS, stylua ok; remaining selene items are warnings only (see gate output).
Studio for Jack: reach L5, hold 2 tickets, both stack under each other; overhead shows title under name.
Question: second-ticket gap (10) and title label position (below name block, y=1.0) were my choice; confirm vs STYLE.
