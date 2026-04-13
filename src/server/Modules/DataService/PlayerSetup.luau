local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

---> lifecycle
local function getFilterResult(text: string, fromUserId: number)
	local filterResult
	local success, errorMessage = pcall(function()
		filterResult = TextService:FilterStringAsync(text, fromUserId)
	end)

	if success then
		return filterResult
	else
		warn("Error generating TextFilterResult:", errorMessage)
		return nil
	end
end

local function formatBrackets(str: string): string
	return str:gsub("%[(.-)%]", " <font color='#f5c242'>%1</font> "):gsub("|(.-)|", " <font color='#fa2545'>%1</font> ")
end

return {
	function(player: Player, proxy) ---> nickname setup
		local current = os.time()
		proxy.Data.Playtime.MostRecentJoin = current
		if proxy.Data.Playtime.FirstJoin ~= 0 then
			return
		end
		proxy.Data.Playtime.FirstJoin = current

		local function chooseNicknameRecursive(errorText: string?)
			local baseMessage = "Choose a roleplay nickname."
			local toAppend = errorText or "This cannot be changed later, so choose wisely!"
			Knit.GetService("DialogService")
				:CreateDialog(player, "TextInputPrompt", {
					Title = "Roleplay Name",
					Text = formatBrackets(`{baseMessage} {toAppend}`),
					PlaceholderText = player.DisplayName,
					CloseText = "Close",
				})
				:andThen(function(nickname)
					if typeof(nickname) ~= "string" or nickname:gsub(" ", "") == "" then
						chooseNicknameRecursive("|Invalid nickname. Please try again.|")
						return
					end

					if #nickname > 15 then
						chooseNicknameRecursive("|Nickname must be 15 characters or less.|")
						return
					end

					local filterResult = getFilterResult(nickname, player.UserId)
					if filterResult then
						local filteredNickname = filterResult:GetNonChatStringForBroadcastAsync()
						if filteredNickname ~= nickname then
							chooseNicknameRecursive("|Nickname contains filtered content. Please try again.|")
							return
						end
						proxy:SetValue({ "Nickname" }, nickname)
						Knit.GetService("CosmeticsService"):NotifyNicknameChanged(player, nickname)
					else
						chooseNicknameRecursive("|An unexpected error occurred. Please try again.|")
						return
					end
				end)
		end
		task.delay(3, chooseNicknameRecursive)
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
