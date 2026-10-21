local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local ShiftConfig = require(ReplicatedStorage.Shared.Configuration.ShiftConfig)

---> constants
local CARD_WAIT_SECONDS = 30

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
					SkipText = "Skip",
				})
				:andThen(function(nickname)
					if nickname == nil or nickname == "" then
						player:SetAttribute("NicknamePending", nil)
						return -- Skip, or an empty Submit: keep DisplayName
					end

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
						player:SetAttribute("NicknamePending", nil)
					else
						chooseNicknameRecursive("|An unexpected error occurred. Please try again.|")
						return
					end
				end)
		end

		-- The prompt waits for the end of the first shift (summary.First) and for the shift card to close.
		-- The listener only sets an attribute and schedules; it never yields (it runs inside ShiftService:_endShift).
		task.defer(function()
			local ok, err = pcall(function()
				local connection
				local gaveUp = false
				connection = Knit.GetService("ShiftService").ShiftEnding:Connect(function(shiftPlayer, summary)
					if shiftPlayer ~= player or not (summary.First or gaveUp) then
						return
					end
					player:SetAttribute("NicknamePending", true)
					task.delay(ShiftConfig.CARD_SECONDS_FIRST, function()
						local waited = 0
						while
							player.Parent ~= nil
							and player:GetAttribute("ShiftCardOpen") == true
							and waited < CARD_WAIT_SECONDS
						do
							task.wait(1)
							waited += 1
						end
						if player.Parent == nil or player:GetAttribute("ShiftCardOpen") == true then
							gaveUp = true -- the hook stays for the next shift end
							player:SetAttribute("NicknamePending", nil)
							return
						end
						connection:Disconnect()
						chooseNicknameRecursive()
					end)
				end)
			end)
			if not ok then
				warn("[PlayerSetup] Nickname hook failed:", err)
			end
		end)
	end,
	function(player: Player, proxy) ---> cosmetics replication
		Knit.GetService("CosmeticsService"):SetupPlayerCosmetics(player, proxy)
		Knit.GetService("PetService"):SetupPlayerPets(player, proxy)
	end,
}
