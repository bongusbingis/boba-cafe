local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

---> lifecycle
return {
	function(_player: Player, proxy) ---> join timestamps
		-- The nickname prompt used to fire from here, 3s into a first join, and could not
		-- be dismissed. It is now deferred to OnboardingService, which runs it once the
		-- player has actually started playing (see DataService:PromptNickname).
		local current = os.time()
		proxy.Data.Playtime.MostRecentJoin = current
		if proxy.Data.Playtime.FirstJoin == 0 then
			proxy.Data.Playtime.FirstJoin = current
		end
	end,
	function(player: Player, proxy) ---> cosmetics replication
		Knit.GetService("CosmeticsService"):SetupPlayerCosmetics(player, proxy)
		Knit.GetService("PetService"):SetupPlayerPets(player, proxy)
	end,
	function(player: Player, proxy) ---> grant free group pet
		xpcall(function()
			if player:IsInGroupAsync(3174578) then
				local freeItemsRedeemed = proxy.Data.Inventory.FreeItemsRedeemed
				if table.find(freeItemsRedeemed, "GroupPet") then
					return
				end

				table.insert(freeItemsRedeemed, "GroupPet")
				proxy:SetValue({ "Inventory", "Items", "Pets", HttpService:GenerateGUID(false)}, {
					Name = "Ant Pet",
					Tier = "Basic",
					Equipped = false,
					Properties = {},
				})
			end
		end, function(err)
			warn(err)
		end)
	end,
	
}
