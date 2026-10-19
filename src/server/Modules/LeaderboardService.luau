--!strict
--[[
	LeaderboardService.luau
	Knit service managing the 5 monthly OrderedDataStores, automated monthly resets,
	in-world SurfaceGui refresh, and top barista statues (REVIVAL-001 M4-LEADERBOARDS, DEC-032).
]]

---> services
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local LeaderboardConfig = require(Shared.Configuration.LeaderboardConfig)
local WorldPath = require(Shared.Utility.WorldPath)

---> constants
local WORLD_WAIT_SECONDS = 10

---> service declaration
local LeaderboardService = Knit.CreateService({
	Name = "LeaderboardService",
	Client = {},
})

LeaderboardService.Enabled = false
LeaderboardService._nameCache = {} :: { [number]: string }
LeaderboardService._mockOrderedDataStore = nil :: ((name: string) -> any)?
LeaderboardService._mockPlayers = nil :: any?
LeaderboardService._loopRunning = false

---> private helpers
function LeaderboardService:_getOrderedDataStore(name: string): any
	if self._mockOrderedDataStore then
		return self._mockOrderedDataStore(name)
	end
	return DataStoreService:GetOrderedDataStore(name)
end

function LeaderboardService:_getPlayersService(): any
	return self._mockPlayers or Players
end

function LeaderboardService:_getUsername(userId: number): string
	if self._nameCache[userId] then
		return self._nameCache[userId]
	end

	local playersService = self:_getPlayersService()
	local onlinePlayer = playersService:GetPlayerByUserId(userId)
	if onlinePlayer then
		self._nameCache[userId] = onlinePlayer.Name
		return onlinePlayer.Name
	end

	local ok, name = pcall(function()
		return playersService:GetNameFromUserIdAsync(userId)
	end)
	if ok and typeof(name) == "string" and name ~= "" then
		self._nameCache[userId] = name
		return name
	end

	return `User_{userId}`
end

function LeaderboardService:_updatePlayerStat(userId: number, boardType: string, delta: number): boolean
	local monthKey = LeaderboardConfig.GetMonthKey(boardType)
	local ok, err = pcall(function()
		local store = self:_getOrderedDataStore(monthKey)
		if not store then
			return
		end
		store:UpdateAsync(tostring(userId), function(oldValue)
			local current = typeof(oldValue) == "number" and oldValue or 0
			return math.max(0, math.floor(current + delta))
		end)
	end)
	if not ok then
		warn(`[LeaderboardService] Failed to update stat for {userId} on {boardType}: {err}`)
		return false
	end
	return true
end

function LeaderboardService:_formatEntriesText(entries: { { UserId: number, Name: string, Value: number } }): string
	local lines = {}
	for i = 1, LeaderboardConfig.TOP_LIMIT do
		local entry = entries[i]
		if entry then
			table.insert(lines, `{i}. {entry.Name} - {entry.Value}`)
		else
			table.insert(lines, `{i}. ---`)
		end
	end
	return table.concat(lines, "\n")
end

function LeaderboardService:_updateBoardGui(
	boardModel: Model,
	boardDef: LeaderboardConfig.BoardDefinition,
	entries: { { UserId: number, Name: string, Value: number } }
)
	local part = boardModel:FindFirstChild("Part")
	local surfaceGui = if part
		then part:FindFirstChildOfClass("SurfaceGui")
		else boardModel:FindFirstChildWhichIsA("SurfaceGui", true)
	if not surfaceGui then
		return
	end

	-- Update title label (TimePeriod, Title, or Header)
	local titleLabel = surfaceGui:FindFirstChild("Title")
		or surfaceGui:FindFirstChild("TimePeriod")
		or surfaceGui:FindFirstChild("Header")

	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = boardDef.BoardName
	end

	-- Update any TextLabel that still holds the legacy "Most Staff Points" text
	for _, desc in surfaceGui:GetDescendants() do
		if desc:IsA("TextLabel") and desc.Text == "Most Staff Points" then
			desc.Text = "Most Orders Served"
		end
	end

	-- Update entries label (TextLabel, Entries, or List)
	local entriesLabel = surfaceGui:FindFirstChild("Entries")
		or surfaceGui:FindFirstChild("List")
		or surfaceGui:FindFirstChild("TextLabel")

	if entriesLabel and entriesLabel:IsA("TextLabel") and entriesLabel ~= titleLabel then
		entriesLabel.Text = self:_formatEntriesText(entries)
	end
end

---> public methods

--- Enqueues an asynchronous score increment for player in the monthly OrderedDataStore.
function LeaderboardService:IncrementStat(player: Player, boardType: string, delta: number)
	if not player or typeof(player.UserId) ~= "number" or player.UserId <= 0 then
		return
	end
	if typeof(delta) ~= "number" or delta <= 0 then
		return
	end
	if not LeaderboardConfig.BOARDS[boardType] then
		warn(`[LeaderboardService] Unknown board type: {boardType}`)
		return
	end

	task.spawn(function()
		self:_updatePlayerStat(player.UserId, boardType, delta)
	end)
end

--- Queries the current month's OrderedDataStore and returns the top entries with cached usernames.
function LeaderboardService:GetTopEntries(
	boardType: string,
	limit: number?
): { { UserId: number, Name: string, Value: number } }
	local topLimit = limit or LeaderboardConfig.TOP_LIMIT
	local monthKey = LeaderboardConfig.GetMonthKey(boardType)
	local entries: { { UserId: number, Name: string, Value: number } } = {}

	local ok, err = pcall(function()
		local store = self:_getOrderedDataStore(monthKey)
		if not store then
			return
		end
		local pages = store:GetSortedAsync(false, topLimit)
		local currentPage = pages:GetCurrentPage()
		for _, item in ipairs(currentPage) do
			local uid = tonumber(item.key)
			if uid then
				local name = self:_getUsername(uid)
				table.insert(entries, {
					UserId = uid,
					Name = name,
					Value = item.value,
				})
			end
		end
	end)

	if not ok then
		warn(`[LeaderboardService] Failed to get top entries for {boardType}: {err}`)
	end

	return entries
end

--- Resolves Workspace.OldScriptables.LeaderboardsFolder.Monthly and updates all SurfaceGuis.
--- Automatically renames legacy "Most Staff Points" board to "Most Orders Served".
function LeaderboardService:RefreshBoards()
	local monthlyFolder = WorldPath.find(Workspace, { "OldScriptables", "LeaderboardsFolder", "Monthly" })
	if not monthlyFolder then
		return
	end

	for boardType, boardDef in LeaderboardConfig.BOARDS do
		local entries = self:GetTopEntries(boardType, LeaderboardConfig.TOP_LIMIT)

		for _, child in monthlyFolder:GetChildren() do
			if child:IsA("Model") and (child.Name == boardDef.BoardName or child.Name == boardDef.ModelName) then
				if child.Name ~= boardDef.BoardName then
					child.Name = boardDef.BoardName
				end
				self:_updateBoardGui(child, boardDef, entries)
			end
		end
	end
end

--- Queries the #1 player in OrdersServed and MostTips, resolves LeaderboardsFolder.Statues,
--- and applies their HumanoidDescription.
function LeaderboardService:RefreshStatues()
	local statuesFolder = WorldPath.find(Workspace, { "OldScriptables", "LeaderboardsFolder", "Statues" })
	if not statuesFolder then
		return
	end

	local topWinners: { [string]: { UserId: number, Name: string, Value: number }? } = {
		OrdersServed = self:GetTopEntries("OrdersServed", 1)[1],
		MostTips = self:GetTopEntries("MostTips", 1)[1],
		TopDonators = self:GetTopEntries("TopDonators", 1)[1],
	}

	local playersService = self:_getPlayersService()
	local children = statuesFolder:GetChildren()

	for index, child in ipairs(children) do
		if not child:IsA("Model") then
			continue
		end

		local winner: { UserId: number, Name: string, Value: number }? = nil
		local config = child:FindFirstChild("Configuration")

		if config then
			local lbObj = config:FindFirstChild("Leaderboard")
			if lbObj and lbObj:IsA("ObjectValue") and lbObj.Value then
				local targetName = lbObj.Value.Name
				if targetName == "Most Staff Points" or targetName == "Most Orders Served" then
					winner = topWinners.OrdersServed
				elseif targetName == "Most Tips" then
					winner = topWinners.MostTips
				elseif targetName == "Top Donators" then
					winner = topWinners.TopDonators
				end
			end

			if not winner then
				local roleObj = config:FindFirstChild("Role")
				if roleObj and roleObj:IsA("StringValue") then
					local roleVal = roleObj.Value
					if string.find(roleVal, "Donator") then
						winner = topWinners.TopDonators
					elseif string.find(roleVal, "Tip") then
						winner = topWinners.MostTips
					elseif
						string.find(roleVal, "Order")
						or string.find(roleVal, "Staff")
						or string.find(roleVal, "Barista")
					then
						winner = topWinners.OrdersServed
					end
				end
			end
		end

		-- Fallback by index: statue 1 = OrdersServed / TopDonators, statue 2 = MostTips
		if not winner then
			if index == 1 then
				winner = topWinners.OrdersServed or topWinners.TopDonators
			elseif index == 2 then
				winner = topWinners.MostTips
			end
		end

		if winner and winner.UserId > 0 then
			local ok, desc = pcall(function()
				return playersService:GetHumanoidDescriptionFromUserId(winner.UserId)
			end)
			local humanoid = child:FindFirstChildOfClass("Humanoid")
			if humanoid then
				if ok and desc then
					pcall(function()
						humanoid:ApplyDescription(desc)
					end)
				end
				humanoid.DisplayName = winner.Name
			end
		end
	end
end

---> lifecycle
function LeaderboardService:KnitStart()
	local leaderboardsFolder =
		WorldPath.waitFor(Workspace, { "OldScriptables", "LeaderboardsFolder" }, WORLD_WAIT_SECONDS)
	if not leaderboardsFolder then
		warn("[LeaderboardService] LeaderboardsFolder not found; leaderboard system disabled cleanly")
		self.Enabled = false
		return
	end

	self.Enabled = true
	self.LeaderboardsFolder = leaderboardsFolder

	task.spawn(function()
		self:RefreshBoards()
		self:RefreshStatues()
	end)

	if not self._loopRunning then
		self._loopRunning = true
		task.spawn(function()
			while self.Enabled do
				task.wait(LeaderboardConfig.REFRESH_INTERVAL_SECONDS)
				if not self.Enabled then
					break
				end
				self:RefreshBoards()
				self:RefreshStatues()
			end
			self._loopRunning = false
		end)
	end
end

return LeaderboardService
