--!strict

--
-- Registry for game-specific behavior.
-- Keep inventory generic: actions live here, not inside InventoryItem.
--
-- Example:
-- return {
-- 	Nametags = {
-- 		Royal = function(ctx)
-- 			ctx.item:SetProperty("ActivatedAt", os.time())
-- 		end,
-- 	},
-- 	Pets = {
-- 		BobaBear = function(ctx)
-- 			ctx.services.PetService:Equip(ctx.player, ctx.item:GetId())
-- 		end,
-- 	},
-- }
--

return {}
