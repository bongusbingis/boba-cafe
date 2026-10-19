RESULT: PASS
Changed: RealOrderConfig.luau (new), RealOrderService.luau (new), OrderService.luau (OrderCreated/OrderPickedUp signals, auto-dispatch fallback in _tryDispatchFromQueue using _freeSince, re-dispatch on clock-in/deposit/pick-up), ProfileTemplate.luau (RegularOrders), Tests/RealOrder.spec.luau.
Gate: PASS on all 5 files (no new findings).
Studio (Jack): 3-client test, two baristas + one customer; bubble, auto-assign, x2 pay x3 then x1, drink kept, RegularOrders.
Notes: _handlePickUp already gives tools to the customer (nothing added; MadeBy set in RealOrderService). OrderPickedUp has a 6th arg (order items) because specs lack Category for Rules.Payout. Notify uses Title/Description (+Text). Hearts/beam not done.
