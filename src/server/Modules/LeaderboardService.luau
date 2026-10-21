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
local Styles = require(Shared.UI.Styles)
local WorldPath = require(Shared.Utility.WorldPath)

---> constants
local ACTIVE_MINUTE_SECONDS = 60
local FLUSH_ON_CLOSE_WAIT_SECONDS = 25

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
LeaderboardService._flushLoopRunning = false
LeaderboardService._activeLoopRunning = false
-- Batched score deltas awaiting one DataStore write per (user, board) per flush.
LeaderboardService._pending = {} :: { [number]: { [string]: number } }
LeaderboardService._inflight = 0
-- Set when BindToClose starts: failed writes are dropped instead of re-queued.
LeaderboardService._closing = false
-- Failed write attempts per (user, board) for the delta currently being retried.
LeaderboardService._flushFailures = {} :: { [number]: { [string]: number } }

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

function LeaderboardService:_findSurfaceGui(boardModel: Model): SurfaceGui?
	local part = boardModel:FindFirstChild("Part")
	return if part
		then part:FindFirstChildOfClass("SurfaceGui")
		else boardModel:FindFirstChildWhichIsA("SurfaceGui", true)
end

--- Handles the result of one flush write. A failed delta goes back into _pending (retried by the next
--- flush) up to FLUSH_MAX_ATTEMPTS total attempts, and is dropped once shutdown has begun. A delta lives in
--- exactly one place at a time (pending or in flight), so a re-queue cannot double-count; the queue is
--- bounded by users x boards. Residual case: if UpdateAsync throws after Roblox already committed the
--- write, a retry could add the delta twice; accepted (rare, monthly board).
function LeaderboardService:_settleFlush(userId: number, boardType: string, delta: number, ok: boolean)
	local failures = self._flushFailures[userId]
	if ok then
		if failures then
			failures[boardType] = nil
			if next(failures) == nil then
				self._flushFailures[userId] = nil
			end
		end
		return
	end

	if not failures then
		failures = {}
		self._flushFailures[userId] = failures
	end
	local attempts = (failures[boardType] or 0) + 1
	if self._closing or attempts >= LeaderboardConfig.FLUSH_MAX_ATTEMPTS then
		warn(`[LeaderboardService] Dropping {delta} for {userId} on {boardType} after {attempts} attempts`)
		failures[boardType] = nil
		if next(failures) == nil then
			self._flushFailures[userId] = nil
		end
		return
	end

	failures[boardType] = attempts
	local userBoards = self._pending[userId]
	if not userBoards then
		userBoards = {}
		self._pending[userId] = userBoards
	end
	userBoards[boardType] = (userBoards[boardType] or 0) + delta
end

--- Writes pending deltas (all users, or one user) with one _updatePlayerStat per (user, board).
--- Returns immediately; writes run in spawned tasks tracked by _inflight.
function LeaderboardService:_flushPending(onlyUserId: number?)
	local snapshot: { [number]: { [string]: number } } = {}
	for userId, boards in self._pending do
		if onlyUserId == nil or onlyUserId == userId then
			snapshot[userId] = boards
			self._pending[userId] = nil
		end
	end

	for userId, boards in snapshot do
		for boardType, delta in boards do
			self._inflight += 1
			task.spawn(function()
				local ok = self:_updatePlayerStat(userId, boardType, delta)
				self:_settleFlush(userId, boardType, delta, ok)
				self._inflight -= 1
			end)
		end
	end
end

local function formatNumber(n: number): string
	local formatted = tostring(math.floor(n))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

function LeaderboardService:_renderTabularContent(
	surfaceGui: SurfaceGui,
	boardDef: LeaderboardConfig.BoardDefinition,
	entries: { { UserId: number, Name: string, Value: number } }
)
	local container = surfaceGui:FindFirstChild("TableContainer") :: Frame?
	if not container then
		container = Instance.new("Frame")
		container.Name = "TableContainer"
		container.Size = UDim2.new(1, -24, 1, -24)
		container.Position = UDim2.fromScale(0.5, 0.5)
		container.AnchorPoint = Vector2.new(0.5, 0.5)
		container.BackgroundColor3 = Styles.OFFWHITE
		container.BorderSizePixel = 0

		local stroke = Instance.new("UIStroke")
		stroke.Color = Styles.GREEN_LIGHT
		stroke.Thickness = 3
		stroke.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = container

		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = container

		-- Table Header Row
		local headerRow = Instance.new("Frame")
		headerRow.Name = "HeaderRow"
		headerRow.Size = UDim2.new(1, 0, 0, 48)
		headerRow.Position = UDim2.fromOffset(0, 0)
		headerRow.BackgroundColor3 = Styles.GREEN
		headerRow.BorderSizePixel = 0

		local headerCorner = Instance.new("UICorner")
		headerCorner.CornerRadius = UDim.new(0, 6)
		headerCorner.Parent = headerRow

		local rankHeader = Instance.new("TextLabel")
		rankHeader.Name = "RankHeader"
		rankHeader.Size = UDim2.fromScale(0.18, 1)
		rankHeader.Position = UDim2.fromOffset(0, 0)
		rankHeader.BackgroundTransparency = 1
		rankHeader.Text = "RANK"
		rankHeader.FontFace = Styles.FONT_FREDOKA
		rankHeader.TextSize = 22
		rankHeader.TextColor3 = Color3.new(1, 1, 1)
		rankHeader.TextXAlignment = Enum.TextXAlignment.Center
		rankHeader.Parent = headerRow

		local playerHeader = Instance.new("TextLabel")
		playerHeader.Name = "PlayerHeader"
		playerHeader.Size = UDim2.new(0.52, -12, 1, 0)
		playerHeader.Position = UDim2.new(0.18, 12, 0, 0)
		playerHeader.BackgroundTransparency = 1
		playerHeader.Text = "BARISTA"
		playerHeader.FontFace = Styles.FONT_FREDOKA
		playerHeader.TextSize = 22
		playerHeader.TextColor3 = Color3.new(1, 1, 1)
		playerHeader.TextXAlignment = Enum.TextXAlignment.Left
		playerHeader.Parent = headerRow

		local metricHeader = Instance.new("TextLabel")
		metricHeader.Name = "MetricHeader"
		metricHeader.Size = UDim2.new(0.30, -16, 1, 0)
		metricHeader.Position = UDim2.fromScale(0.70, 0)
		metricHeader.BackgroundTransparency = 1
		metricHeader.Text = string.upper(boardDef.Metric or "SCORE")
		metricHeader.FontFace = Styles.FONT_FREDOKA
		metricHeader.TextSize = 22
		metricHeader.TextColor3 = Color3.new(1, 1, 1)
		metricHeader.TextXAlignment = Enum.TextXAlignment.Right
		metricHeader.Parent = headerRow

		headerRow.Parent = container

		-- List of rows
		local rowsFrame = Instance.new("Frame")
		rowsFrame.Name = "RowsList"
		rowsFrame.Size = UDim2.new(1, 0, 1, -54)
		rowsFrame.Position = UDim2.fromOffset(0, 54)
		rowsFrame.BackgroundTransparency = 1

		local listLayout = Instance.new("UIListLayout")
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, 4)
		listLayout.Parent = rowsFrame

		rowsFrame.Parent = container
		container.Parent = surfaceGui
	end

	local headerRow = container:FindFirstChild("HeaderRow")
	if headerRow then
		local metricHeader = headerRow:FindFirstChild("MetricHeader")
		if metricHeader and metricHeader:IsA("TextLabel") then
			metricHeader.Text = string.upper(boardDef.Metric or "SCORE")
		end
	end

	local rowsFrame = container:FindFirstChild("RowsList")
	if not rowsFrame then
		return
	end

	for i = 1, LeaderboardConfig.TOP_LIMIT do
		local rowName = `Row_{i}`
		local row = rowsFrame:FindFirstChild(rowName) :: Frame?
		if not row then
			row = Instance.new("Frame")
			row.Name = rowName
			row.Size = UDim2.new(1, 0, 0, 68)
			row.LayoutOrder = i
			row.BorderSizePixel = 0

			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 6)
			rowCorner.Parent = row

			if i == 1 then
				row.BackgroundColor3 = Color3.fromRGB(255, 248, 220)
				local goldStroke = Instance.new("UIStroke")
				goldStroke.Name = "GoldStroke"
				goldStroke.Color = Styles.GOLD_MID
				goldStroke.Thickness = 1.5
				goldStroke.Parent = row
			elseif i % 2 == 0 then
				row.BackgroundColor3 = Color3.fromRGB(242, 247, 240)
			else
				row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			end

			local rankLabel = Instance.new("TextLabel")
			rankLabel.Name = "Rank"
			rankLabel.Size = UDim2.fromScale(0.18, 1)
			rankLabel.Position = UDim2.fromOffset(0, 0)
			rankLabel.BackgroundTransparency = 1
			rankLabel.FontFace = Styles.FONT_FREDOKA
			rankLabel.TextSize = 24
			rankLabel.Text = `#{i}`
			rankLabel.TextXAlignment = Enum.TextXAlignment.Center
			if i == 1 then
				rankLabel.TextColor3 = Styles.GOLD_DEEP
			elseif i == 2 then
				rankLabel.TextColor3 = Color3.fromRGB(120, 130, 140)
			elseif i == 3 then
				rankLabel.TextColor3 = Color3.fromRGB(175, 110, 60)
			else
				rankLabel.TextColor3 = Styles.GREEN_DEEP
			end
			rankLabel.Parent = row

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "Name"
			nameLabel.Size = UDim2.new(0.52, -12, 1, 0)
			nameLabel.Position = UDim2.new(0.18, 12, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.FontFace = Styles.FONT_FREDOKA
			nameLabel.TextSize = 22
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.Parent = row

			local valueLabel = Instance.new("TextLabel")
			valueLabel.Name = "Value"
			valueLabel.Size = UDim2.new(0.30, -16, 1, 0)
			valueLabel.Position = UDim2.fromScale(0.70, 0)
			valueLabel.BackgroundTransparency = 1
			valueLabel.FontFace = Styles.FONT_FREDOKA
			valueLabel.TextSize = 22
			valueLabel.TextXAlignment = Enum.TextXAlignment.Right
			valueLabel.Parent = row

			row.Parent = rowsFrame
		end

		local entry = entries[i]
		local nameLabel = row:FindFirstChild("Name")
		if nameLabel and nameLabel:IsA("TextLabel") then
			if entry then
				nameLabel.Text = entry.Name
				nameLabel.TextColor3 = Styles.GREEN_DEEP
			else
				nameLabel.Text = "---"
				nameLabel.TextColor3 = Styles.GRAY
			end
		end

		local valueLabel = row:FindFirstChild("Value")
		if valueLabel and valueLabel:IsA("TextLabel") then
			if entry then
				valueLabel.Text = formatNumber(entry.Value)
				valueLabel.TextColor3 = Styles.GREEN_DEEP
			else
				valueLabel.Text = "---"
				valueLabel.TextColor3 = Styles.GRAY
			end
		end
	end
end

function LeaderboardService:_updateBoardGui(
	boardModel: Model,
	boardDef: LeaderboardConfig.BoardDefinition,
	entries: { { UserId: number, Name: string, Value: number } }
)
	local isHidden = boardDef.Hidden == true

	-- 1. Update Header on Part (or MainColor)
	local headerPart = boardModel:FindFirstChild("Part") or boardModel:FindFirstChild("MainColor")
	local headerGui = if headerPart
		then headerPart:FindFirstChildOfClass("SurfaceGui")
		else self:_findSurfaceGui(boardModel)
	if headerGui then
		if isHidden then
			headerGui.Enabled = false
		else
			headerGui.Enabled = true

			local titleLabel = headerGui:FindFirstChild("TextLabel")
			if not titleLabel or not titleLabel:IsA("TextLabel") then
				titleLabel = headerGui:FindFirstChild("Title") or headerGui:FindFirstChild("Header")
			end
			if titleLabel and titleLabel:IsA("TextLabel") then
				titleLabel.Text = boardDef.BoardName
				titleLabel.FontFace = Styles.FONT_FREDOKA
				titleLabel.TextColor3 = Color3.new(1, 1, 1)
			end

			local timePeriodLabel = headerGui:FindFirstChild("TimePeriod")
			if timePeriodLabel and timePeriodLabel:IsA("TextLabel") then
				local isGlobal = boardModel.Parent and boardModel.Parent.Name == "Global"
				if isGlobal then
					timePeriodLabel.Text = "All Time"
				else
					timePeriodLabel.Text = DateTime.now():FormatUniversalTime("MMMM YYYY", "en-us")
				end
				timePeriodLabel.FontFace = Styles.FONT_FREDOKA
				timePeriodLabel.TextColor3 = Styles.GOLD
			end

			for _, desc in headerGui:GetDescendants() do
				if desc:IsA("TextLabel") and desc.Text == "Most Staff Points" then
					desc.Text = "Most Orders Served"
				end
			end
		end
	end

	-- 2. Update Content on Union
	local unionPart = boardModel:FindFirstChild("Union")
	if unionPart and unionPart:IsA("BasePart") then
		local contentGui = unionPart:FindFirstChild("LeaderboardContentGui") :: SurfaceGui?
		if not contentGui then
			contentGui = unionPart:FindFirstChildOfClass("SurfaceGui")
			if contentGui then
				contentGui.Name = "LeaderboardContentGui"
			end
		end

		if not contentGui then
			contentGui = Instance.new("SurfaceGui")
			contentGui.Name = "LeaderboardContentGui"
			contentGui.Face = Enum.NormalId.Back
			contentGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			contentGui.PixelsPerStud = 100
			contentGui.CanvasSize = Vector2.new(800, 850)
			contentGui.LightInfluence = 1
			contentGui.Parent = unionPart
		end

		if isHidden then
			contentGui.Enabled = false
		else
			contentGui.Enabled = true
			self:_renderTabularContent(contentGui, boardDef, entries)
		end
	end
end

---> public methods

--- Adds a score increment for player to the in-memory batch; flushed to the monthly
--- OrderedDataStore every REFRESH_INTERVAL_SECONDS, on PlayerRemoving and on server close.
function LeaderboardService:IncrementStat(player: Player, boardType: string, delta: number)
	if not player or typeof(player.UserId) ~= "number" or player.UserId <= 0 then
		return
	end
	if typeof(delta) ~= "number" or delta <= 0 then
		return
	end
	local boardDef = LeaderboardConfig.BOARDS[boardType]
	if not boardDef then
		warn(`[LeaderboardService] Unknown board type: {boardType}`)
		return
	end
	if boardDef.Hidden then
		return
	end

	local userBoards = self._pending[player.UserId]
	if not userBoards then
		userBoards = {}
		self._pending[player.UserId] = userBoards
	end
	userBoards[boardType] = (userBoards[boardType] or 0) + delta
end

--- Credits a granted donation to Top Donators. Unlike IncrementStat this records even while the board is
--- Hidden (DEC-035 Q4), so the monthly store is already populated if Jack unhides it; hidden boards are still
--- never queried or displayed. Called by DonationReceipts only after PurchaseGranted.
function LeaderboardService:CreditDonation(player: Player, robux: number)
	if not player or typeof(player.UserId) ~= "number" or player.UserId <= 0 then
		return
	end
	if typeof(robux) ~= "number" or robux <= 0 then
		return
	end
	local userBoards = self._pending[player.UserId]
	if not userBoards then
		userBoards = {}
		self._pending[player.UserId] = userBoards
	end
	userBoards.TopDonators = (userBoards.TopDonators or 0) + math.floor(robux)
end

--- Flushes all batched increments now. Used on shutdown and by tests.
function LeaderboardService:FlushAll()
	self:_flushPending(nil)
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

--- Resolves Workspace.Assets.LeaderboardsFolder.Monthly (or OldScriptables) and updates all SurfaceGuis.
--- Automatically renames legacy "Most Staff Points" board to "Most Orders Served".
function LeaderboardService:RefreshBoards()
	local monthlyFolder = if self.LeaderboardsFolder
		then self.LeaderboardsFolder:FindFirstChild("Monthly")
		else WorldPath.find(Workspace, { "Assets", "LeaderboardsFolder", "Monthly" })
	if not monthlyFolder then
		monthlyFolder = WorldPath.find(Workspace, { "OldScriptables", "LeaderboardsFolder", "Monthly" })
	end
	if not monthlyFolder then
		return
	end

	for boardType, boardDef in LeaderboardConfig.BOARDS do
		-- Hidden boards (DEC-035 Q4) are never queried; their SurfaceGui is disabled at runtime.
		local entries = if boardDef.Hidden then {} else self:GetTopEntries(boardType, LeaderboardConfig.TOP_LIMIT)

		for _, child in monthlyFolder:GetChildren() do
			if child:IsA("Model") and (child.Name == boardDef.BoardName or child.Name == boardDef.ModelName) then
				if child.Name ~= boardDef.BoardName then
					child.Name = boardDef.BoardName
				end
				self:_updateBoardGui(child, boardDef, entries)
			end
		end
	end

	local globalFolder = if self.LeaderboardsFolder
		then self.LeaderboardsFolder:FindFirstChild("Global")
		else WorldPath.find(Workspace, { "Assets", "LeaderboardsFolder", "Global" })
	if globalFolder then
		for boardType, boardDef in LeaderboardConfig.BOARDS do
			local entries = if boardDef.Hidden then {} else self:GetTopEntries(boardType, LeaderboardConfig.TOP_LIMIT)
			for _, child in globalFolder:GetChildren() do
				if child:IsA("Model") and (child.Name == boardDef.BoardName or child.Name == boardDef.ModelName) then
					if child.Name ~= boardDef.BoardName then
						child.Name = boardDef.BoardName
					end
					self:_updateBoardGui(child, boardDef, entries)
				end
			end
		end
	end
end

--- Queries the #1 player in OrdersServed and MostBobaBucks, resolves LeaderboardsFolder.Statues,
--- and applies their HumanoidDescription. Statue 1 (Orders/Staff/Barista) shows OrdersServed;
--- statue 2 (formerly Most Tips) shows MostBobaBucks (DEC-037 Q13). Hidden boards feed no
--- statue: a Top Donators statue gets no winner and is left as it is.
function LeaderboardService:RefreshStatues()
	local statuesFolder = if self.LeaderboardsFolder
		then self.LeaderboardsFolder:FindFirstChild("Statues")
		else WorldPath.find(Workspace, { "Assets", "LeaderboardsFolder", "Statues" })
	if not statuesFolder then
		statuesFolder = WorldPath.find(Workspace, { "OldScriptables", "LeaderboardsFolder", "Statues" })
	end
	if not statuesFolder then
		return
	end

	local topWinners: { [string]: { UserId: number, Name: string, Value: number }? } = {
		OrdersServed = self:GetTopEntries("OrdersServed", 1)[1],
		MostBobaBucks = self:GetTopEntries("MostBobaBucks", 1)[1],
	}

	local playersService = self:_getPlayersService()
	local children = statuesFolder:GetChildren()

	for index, child in ipairs(children) do
		if not child:IsA("Model") then
			continue
		end

		local winner: { UserId: number, Name: string, Value: number }? = nil
		local isDonatorStatue = false
		local config = child:FindFirstChild("Configuration")

		if config then
			local lbObj = config:FindFirstChild("Leaderboard")
			if lbObj and lbObj:IsA("ObjectValue") and lbObj.Value then
				local targetName = lbObj.Value.Name
				if targetName == "Most Staff Points" or targetName == "Most Orders Served" then
					winner = topWinners.OrdersServed
				elseif targetName == "Most Tips" or targetName == "Most Boba Bucks" then
					winner = topWinners.MostBobaBucks
				elseif targetName == "Top Donators" then
					isDonatorStatue = true
				end
			end

			if not winner and not isDonatorStatue then
				local roleObj = config:FindFirstChild("Role")
				if roleObj and roleObj:IsA("StringValue") then
					local roleVal = roleObj.Value
					if string.find(roleVal, "Donator") then
						isDonatorStatue = true
					elseif string.find(roleVal, "Tip") or string.find(roleVal, "Boba Bucks") then
						winner = topWinners.MostBobaBucks
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

		-- Fallback by index: statue 1 = OrdersServed, statue 2 = MostBobaBucks (was MostTips)
		if not winner and not isDonatorStatue then
			if index == 1 then
				winner = topWinners.OrdersServed
			elseif index == 2 then
				winner = topWinners.MostBobaBucks
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
	-- Batch flush + MostActive tick run even if the in-world boards are missing.
	Players.PlayerRemoving:Connect(function(player)
		self:_flushPending(player.UserId)
	end)

	game:BindToClose(function()
		self._closing = true
		self:FlushAll()
		local deadline = os.clock() + FLUSH_ON_CLOSE_WAIT_SECONDS
		while self._inflight > 0 and os.clock() < deadline do
			task.wait()
		end
	end)

	if not self._flushLoopRunning then
		self._flushLoopRunning = true
		task.spawn(function()
			while true do
				task.wait(LeaderboardConfig.REFRESH_INTERVAL_SECONDS)
				self:FlushAll()
			end
		end)
	end

	-- MostActive: +1 per player per minute.
	if not self._activeLoopRunning then
		self._activeLoopRunning = true
		task.spawn(function()
			while true do
				task.wait(ACTIVE_MINUTE_SECONDS)
				for _, player in self:_getPlayersService():GetPlayers() do
					self:IncrementStat(player, "MostActive", 1)
				end
			end
		end)
	end

	local leaderboardsFolder = workspace:WaitForChild("Assets"):WaitForChild("LeaderboardsFolder")

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
