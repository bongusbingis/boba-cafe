RESULT: PASS
Files: src/client/Modules/SpillController.lua (SharedStorage.Spills -> CleanlinessStorage, 5 refs); UI filter in src/shared/UI/Pages/{Menu/FoodMenu,MobileOrder/init,Ordering/init}.luau (launch-only FoodTable copy via Menu.IsLaunchItem; RequiredSelection options filtered by Menu.LaunchChoices; visuals unchanged). CategoryPage/ItemPage unchanged (use filtered props).
Gate: PASS (selene new=0, rojo build ok; SpillController has pre-existing stylua drift, not reformatted).
v4 CleanlinessStorage children: Spills, Sparkles, Animations, Tools, BoardInterface; all client needs present. No STOP-AND-ASK.
For Jack later: open order UI (Ordering, MobileOrder, Food Menu) and confirm only launch items/flavours show; trip on a spill and confirm animation/board.
