local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local ShiftConfig = require(ReplicatedStorage.Shared.Configuration.ShiftConfig)

---> constants
local CARD_WAIT_SECONDS = 30
local PROMPT_TIMEOUT_SECONDS = 120 -- DialogService resolves nil after this

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
		if proxy.Data.Playtime.FirstJoin == 0 then
			proxy.Data.Playtime.FirstJoin = current
		end
		-- Offered at a shift end on every join until the player submits a nickname or presses Skip
		-- (REVIEW-FIX P2-3). A timeout, a leave or an empty Submit is not an answer.
		if proxy.Data.Nickname ~= "" or proxy.Data.NicknameSkipped == true then
			return
		end

		local connection: any = nil
		local removing: any = nil
		local listen: () -> ()

		local function cleanup()
			if connection ~= nil then
				connection:Disconnect()
				connection = nil
			end
			if removing ~= nil then
				removing:Disconnect()
				removing = nil
			end
		end

		local function chooseNicknameRecursive(errorText: string?)
			local baseMessage = "Choose a roleplay nickname."
			local toAppend = errorText or "This cannot be changed later, so choose wisely!"
			local openedAt = os.clock()
			Knit.GetService("DialogService")
				:CreateDialog(player, "TextInputPrompt", {
					Title = "Roleplay Name",
					Text = formatBrackets(`{baseMessage} {toAppend}`),
					PlaceholderText = player.DisplayName,
					CloseText = "Close",
					SkipText = "Skip",
				}, PROMPT_TIMEOUT_SECONDS)
				:andThen(function(nickname)
					if nickname == "" then
						-- Skip: keep DisplayName and never ask again
						proxy:SetValue({ "NicknameSkipped" }, true)
						pcall(function()
							Knit.GetService("AnalyticsEvents"):OnboardingFunnel(player, 7, "FirstNicknameSet")
							Knit.GetService("AnalyticsEvents"):Funnel(player, 7, "FirstNicknameSet")
						end)
						player:SetAttribute("NicknamePending", nil)
						cleanup()
						return
					end

					if nickname == nil then
						player:SetAttribute("NicknamePending", nil)
						if player.Parent == nil then
							cleanup() -- left: offered again on the next join
						elseif os.clock() - openedAt >= PROMPT_TIMEOUT_SECONDS - 5 then
							listen() -- timed out: offered again at the next shift end
						else
							chooseNicknameRecursive("|Type a nickname, or press Skip.|")
						end
						return
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
						local broadcastOk, filteredNickname = pcall(function()
							return filterResult:GetNonChatStringForBroadcastAsync()
						end)
						if not broadcastOk or typeof(filteredNickname) ~= "string" then
							chooseNicknameRecursive("|Filtering error. Please try again.|")
							return
						end
						if filteredNickname ~= nickname then
							chooseNicknameRecursive("|Nickname contains filtered content. Please try again.|")
							return
						end
						proxy:SetValue({ "Nickname" }, filteredNickname)
						pcall(function()
							Knit.GetService("AnalyticsEvents"):OnboardingFunnel(player, 7, "FirstNicknameSet")
							Knit.GetService("AnalyticsEvents"):Funnel(player, 7, "FirstNicknameSet")
						end)
						Knit.GetService("CosmeticsService"):NotifyNicknameChanged(player, filteredNickname)
						player:SetAttribute("NicknamePending", nil)
						cleanup()
					else
						chooseNicknameRecursive("|An unexpected error occurred. Please try again.|")
						return
					end
				end)
		end

		-- The prompt waits for a shift end and for the shift card to close. The listener only sets an
		-- attribute and schedules; it never yields (it runs inside ShiftService:_endShift).
		listen = function()
			if player.Parent == nil or connection ~= nil then
				return
			end
			connection = Knit.GetService("ShiftService").ShiftEnding:Connect(function(shiftPlayer, summary)
				if shiftPlayer ~= player then
					return
				end
				if player.Parent == nil then
					cleanup()
					return
				end
				-- disconnect before prompting so it cannot show twice; listen() re-arms on a give-up
				if connection ~= nil then
					connection:Disconnect()
					connection = nil
				end
				player:SetAttribute("NicknamePending", true)
				task.delay(summary.Seconds or ShiftConfig.CARD_SECONDS_FIRST, function()
					local waited = 0
					while
						player.Parent ~= nil
						and player:GetAttribute("ShiftCardOpen") == true
						and waited < CARD_WAIT_SECONDS
					do
						task.wait(1)
						waited += 1
					end
					if player.Parent == nil then
						cleanup()
						return
					end
					if player:GetAttribute("ShiftCardOpen") == true then
						player:SetAttribute("NicknamePending", nil)
						listen() -- try again at the next shift end
						return
					end
					chooseNicknameRecursive()
				end)
			end)
		end

		task.defer(function()
			local ok, err = pcall(function()
				removing = player.AncestryChanged:Connect(function()
					if player.Parent == nil then
						cleanup()
					end
				end)
				listen()
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
