RESULT: PASS
GAMEPLAY-MOBILE-TICKET Part A (Part B Lens not run). File: Hud/OrderTicket.luau.
- patienceBar helper shared by slot-2 bar and collapsed bar (LayoutOrder 1, both slots).
- useEffect keyed on orderKey (order.Id or order) expands on new order when TouchEnabled.
- Collapsed header shows order.Label (AtEnd truncate), else "Order Ticket"/"Order Ticket 2".
Gate: selene new=0, stylua ok, rojo build ok. UNVERIFIED: all runtime; Part B thumb-zone overlap measurement.
