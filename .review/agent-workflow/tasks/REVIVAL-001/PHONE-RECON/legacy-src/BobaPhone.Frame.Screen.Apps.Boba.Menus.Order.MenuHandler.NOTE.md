MenuHandler (LocalScript, 361 lines) is an older standalone copy of PhoneMenuController (380 lines). Body is line-for-line the same
navigation / popup / SelectOption / AddToOrder / AddItemToOrder logic. Only these lines differ (full source was read, not saved verbatim):

- L1-4: `local Boba = require(ReplicatedStorage:WaitForChild("Boba"))`, then `local ProductsData = FoodService['FoodTable']`
  (FoodService is an undeclared global; the script is broken as written; ViewportProvider also an undeclared global).
- L62: submit is `PhoneEvent:FireServer("BobaApp","Order",Order)` (PhoneEvent is an undeclared global; the Chat/Jokes scripts use
  `ReplicatedStorage.RemoteStorage.PhoneEvent`). PhoneMenuController instead uses `PhoneServiceReplica:FireServer("PlaceMobileOrder", order)`.
- L308-319: popup close uses two raw Connection vars C1/C2; PhoneMenuController uses `Maid` (`Boba.Packages.Maid`).
- L323-361: category/item build loop runs at top level (no :Start/:Init); PhoneMenuController wraps it in :Start and sets the replica in :Init.

PhoneMenuController is the newer, intended version. Neither can run in the current place (no `ReplicatedStorage.Boba`).
