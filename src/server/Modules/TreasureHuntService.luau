--!strict
---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local TreasureHuntConfig = require(Shared.Configuration.TreasureHuntConfig)
local WorldPath = require(Shared.Utility.WorldPath)

---> constants
local CHEST_SIZE = Vector3.new(3.5, 2.5, 2.5)
local CHEST_COLOR = Color3.fromRGB(165, 110, 40)
local BUILT_BY = "REVIVAL-001-CHESTS"
local DATA_TIMEOUT_SECONDS = 10

---> types
export type TreasureHuntService = typeof(Knit.CreateService({
	Name = "TreasureHuntService",
	Client = {},
}))

---> service declaration
local TreasureHuntService = Knit.CreateService({
	Name = "TreasureHuntService",
	Client = {},
})

TreasureHuntService._nodes = {} :: { BasePart }
TreasureHuntService._occupiedNodes = {} :: { [BasePart]: boolean }
TreasureHuntService._activeChests = {} :: { [Instance]: boolean }
TreasureHuntService._chestToNode = {} :: { [Instance]: BasePart }
TreasureHuntService._nodeToChest = {} :: { [BasePart]: Instance }
TreasureHuntService._claimedChests = {} :: { [Instance]: boolean }
TreasureHuntService._randomSource = Random.new()
TreasureHuntService._started = false

---> private
function TreasureHuntService:_getService(name: string): any
	return Knit.GetService(name)
end

function TreasureHuntService:_createChestInstance(node: BasePart): (BasePart, ProximityPrompt)
	local chest = Instance.new("Part")
	chest.Name = "TreasureChest"
	chest.Size = CHEST_SIZE
	chest.Color = CHEST_COLOR
	chest.Material = Enum.Material.SmoothPlastic
	chest.Anchored = true
	chest.CanCollide = false
	chest.CFrame = node.CFrame * CFrame.new(0, (node.Size.Y + CHEST_SIZE.Y) / 2, 0)
	chest:SetAttribute("BuiltBy", BUILT_BY)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Treasure Chest"
	prompt.ActionText = "Open"
	prompt.HoldDuration = TreasureHuntConfig.PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = TreasureHuntConfig.PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("BuiltBy", BUILT_BY)
	prompt.Parent = chest

	return chest, prompt
end

function TreasureHuntService:_validateDistance(player: Player, chestPosition: Vector3): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not root or not root:IsA("BasePart") then
		return false
	end
	local maxAllowed = TreasureHuntConfig.PROMPT_MAX_DISTANCE + 5
	return (root.Position - chestPosition).Magnitude <= maxAllowed
end

function TreasureHuntService:_clearChestNode(chest: Instance)
	local node = self._chestToNode[chest]
	if node then
		self._occupiedNodes[node] = nil
		self._nodeToChest[node] = nil
		local occupiedVal = node:FindFirstChild("Occupied")
		if occupiedVal and occupiedVal:IsA("BoolValue") then
			occupiedVal.Value = false
		end
	end
	self._activeChests[chest] = nil
	self._chestToNode[chest] = nil
end

function TreasureHuntService:_notifyPlayer(player: Player, title: string, message: string)
	local ok, dialogService = pcall(function()
		return self:_getService("DialogService")
	end)
	if not ok or not dialogService or typeof(dialogService.Notify) ~= "function" then
		warn(`[TreasureHuntService] {title} for {player.Name}: {message}`)
		return
	end
	pcall(function()
		dialogService:Notify(
			player,
			{
				Title = title,
				Description = message,
				Text = title .. ": " .. message,
				Image = "",
			} :: any
		)
	end)
end

function TreasureHuntService:_getMaxChests(): number
	if Workspace:GetAttribute("TreasureFrenzy") == true then
		return 8
	end
	return TreasureHuntConfig.MAX_ACTIVE_CHESTS
end

function TreasureHuntService:_getRespawnDelay(): number
	if Workspace:GetAttribute("TreasureFrenzy") == true then
		return 15
	end
	return TreasureHuntConfig.RESPAWN_DELAY_SECONDS
end

---> public
function TreasureHuntService:InitNodes(folderOrNodes: Instance | { BasePart })
	table.clear(self._nodes)
	if typeof(folderOrNodes) == "table" then
		for _, node in folderOrNodes do
			if typeof(node) == "Instance" and node:IsA("BasePart") then
				table.insert(self._nodes, node)
			end
		end
	elseif typeof(folderOrNodes) == "Instance" then
		for _, child in folderOrNodes:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(self._nodes, child)
			elseif child:IsA("Model") then
				local part = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
				if part then
					table.insert(self._nodes, part)
				end
			end
		end
	end
end

function TreasureHuntService:GetAvailableNodes(): { BasePart }
	local available = {}
	for _, node in self._nodes do
		if not self._occupiedNodes[node] then
			local occupiedVal = node:FindFirstChild("Occupied")
			if not (occupiedVal and occupiedVal:IsA("BoolValue") and occupiedVal.Value) then
				table.insert(available, node)
			end
		end
	end
	return available
end

function TreasureHuntService:PickUnoccupiedNode(): BasePart?
	local available = self:GetAvailableNodes()
	if #available == 0 then
		return nil
	end
	local index = self._randomSource:NextInteger(1, #available)
	return available[index]
end

function TreasureHuntService:GetActiveChestCount(): number
	local count = 0
	for chest, _ in self._activeChests do
		if chest.Parent then
			count += 1
		end
	end
	return count
end

function TreasureHuntService:SpawnChestAtNode(node: BasePart): Instance?
	if self._occupiedNodes[node] then
		return nil
	end
	local occupiedVal = node:FindFirstChild("Occupied")
	if occupiedVal and occupiedVal:IsA("BoolValue") and occupiedVal.Value then
		return nil
	end

	self._occupiedNodes[node] = true
	if occupiedVal and occupiedVal:IsA("BoolValue") then
		occupiedVal.Value = true
	end

	local chest, prompt = self:_createChestInstance(node)
	chest.Parent = Workspace
	self._activeChests[chest] = true
	self._chestToNode[chest] = node
	self._nodeToChest[node] = chest

	prompt.Triggered:Connect(function(player)
		self:ClaimChest(player, chest)
	end)

	chest.AncestryChanged:Connect(function(_, parent)
		if parent == nil and not self._claimedChests[chest] then
			self:_clearChestNode(chest)
		end
	end)

	return chest
end

function TreasureHuntService:SpawnNextChest(): Instance?
	if self:GetActiveChestCount() >= self:_getMaxChests() then
		return nil
	end
	local node = self:PickUnoccupiedNode()
	if not node then
		return nil
	end
	return self:SpawnChestAtNode(node)
end

function TreasureHuntService:SpawnInitialChests()
	local toSpawn = math.min(self:_getMaxChests(), #self._nodes)
	for _ = 1, toSpawn do
		self:SpawnNextChest()
	end
end

function TreasureHuntService:ScheduleRespawn(delaySeconds: number?)
	local delayTime = delaySeconds or self:_getRespawnDelay()
	task.delay(delayTime, function()
		if not self._started then
			return
		end
		self:SpawnNextChest()
	end)
end

function TreasureHuntService:ClaimChest(player: Player, chest: Instance): boolean
	if self._claimedChests[chest] then
		return false
	end

	local node = self._chestToNode[chest]
	local chestPosition: Vector3
	if chest:IsA("BasePart") then
		chestPosition = chest.Position
	elseif chest:IsA("Model") and chest.PrimaryPart then
		chestPosition = chest.PrimaryPart.Position
	elseif node then
		chestPosition = node.Position
	else
		return false
	end

	if not self:_validateDistance(player, chestPosition) then
		return false
	end

	-- Per-player cooldown (DEC-035 Q2). Treasure Frenzy shortens respawn only, never this.
	-- The check and the timestamp write run back to back after the data yield, so two
	-- simultaneous triggers cannot both pass.
	local okData, playerData =
		self:_getService("DataService"):GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()
	if not okData or not playerData then
		warn(`[TreasureHuntService] Player data not loaded for {player.Name}; chest not opened`)
		return false
	end
	if self._claimedChests[chest] then
		return false
	end

	local now = os.time()
	local lastChestTime = if typeof(playerData.LastTreasureChestTime) == "number"
		then playerData.LastTreasureChestTime
		else 0
	local remaining = TreasureHuntConfig.PLAYER_COOLDOWN_SECONDS - (now - lastChestTime)
	if remaining > 0 then
		self:_notifyPlayer(player, "Treasure Chest", `Next treasure chest in {math.ceil(remaining / 60)} min`)
		return false
	end

	self._claimedChests[chest] = true
	playerData:SetValue({ "LastTreasureChestTime" }, now)

	local reward = TreasureHuntConfig.RollReward(self._randomSource)

	local okCurrency, currencyService = pcall(function()
		return self:_getService("CurrencyService")
	end)
	if okCurrency and currencyService and typeof(currencyService.Modify) == "function" then
		currencyService:Modify(player, "BobaBucks", reward.BobaBucks, "TreasureChest")
	end

	if reward.Capsule then
		-- Player keeps the BobaBucks already granted if the capsule can't be given.
		local okCaps, granted, reason = pcall(function()
			return self:_getService("CapsuleService"):GrantEarnedCapsule(player, reward.Capsule)
		end)
		if not okCaps then
			warn(`[TreasureHuntService] Capsule grant error for {player.Name}: {granted}`)
		elseif not granted and reason == "InternalError" then
			warn(`[TreasureHuntService] Capsule grant failed for {player.Name}: {reason}`)
		end
	end

	local okStats, statisticsService = pcall(function()
		return self:_getService("StatisticsService")
	end)
	if okStats and statisticsService and typeof(statisticsService.IncrementStat) == "function" then
		statisticsService:IncrementStat(player, "TreasureChestsFound", 1)
	end

	local okBadge, badgeService = pcall(function()
		return self:_getService("BadgeService")
	end)
	if okBadge and badgeService and typeof(badgeService.AwardBadge) == "function" then
		badgeService:AwardBadge(player, TreasureHuntConfig.BADGE_ID)
	end

	self:_clearChestNode(chest)
	chest:Destroy()

	self:ScheduleRespawn()

	return true
end

---> lifecycle
function TreasureHuntService:KnitStart()
	self._started = true

	local folder = WorldPath.find(Workspace, { "OldScriptables", "ChestNodesFolder" })
	if not folder then
		folder = WorldPath.find(Workspace, { "Assets", "Chests" })
	end
	if not folder then
		folder = WorldPath.waitFor(Workspace, { "OldScriptables", "ChestNodesFolder" }, 5)
	end
	if not folder then
		folder = WorldPath.waitFor(Workspace, { "Assets", "Chests" }, 5)
	end

	if not folder then
		warn(
			"[TreasureHuntService] Chest nodes folder not found at Workspace.OldScriptables.ChestNodesFolder or Workspace.Assets.Chests; disabling chest spawning."
		)
		return
	end

	self:InitNodes(folder)
	self:SpawnInitialChests()

	Workspace:GetAttributeChangedSignal("TreasureFrenzy"):Connect(function()
		if Workspace:GetAttribute("TreasureFrenzy") == true and self._started then
			local needed = self:_getMaxChests() - self:GetActiveChestCount()
			for _ = 1, needed do
				self:SpawnNextChest()
			end
		end
	end)
end

return TreasureHuntService
