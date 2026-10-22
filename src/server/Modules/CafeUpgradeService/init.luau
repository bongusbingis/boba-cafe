--!strict
--[[
	CafeUpgradeService
	BIG-B2 Cafe Upgrades. Players spend BobaBucks at the Cafe Upgrades board to add
	server-wide cosmetic decor (plants, fairy lights); the buyer's name
	goes on the board's plaque. Per-server state: nothing is saved, a new server starts
	bare. Spending is server-authoritative through CurrencyService:TrySpendAsync.

	World: everything is built in code under workspace.CafeUpgrades (BuiltBy = "Opus-B2"),
	placed from CafeUpgradeConfig.PLACEMENT. No authored content is required.
	All upgrades are cosmetic and nonfunctional: no gameplay effects.
]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local CafeUpgradeConfig = require(Shared.Configuration.CafeUpgradeConfig)
local Styles = require(Shared.UI.Styles)
local Builders = require(script.Builders)

---> constants
local DIALOG_TIMEOUT_SECONDS = 60
local MAX_USE_DISTANCE = CafeUpgradeConfig.PROMPT_MAX_DISTANCE + 6

---> service declaration
local CafeUpgradeService = Knit.CreateService({
	Name = "CafeUpgradeService",
	Client = {},
})

CafeUpgradeService._levels = {} :: { [string]: number }
CafeUpgradeService._contributions = {} :: { CafeUpgradeConfig.Contribution }
CafeUpgradeService._pending = {} :: { [string]: boolean }
CafeUpgradeService._busyPlayers = {} :: { [Player]: boolean }
CafeUpgradeService._visuals = {} :: { [string]: { Instance } }
CafeUpgradeService._folder = nil :: Folder?
CafeUpgradeService._board = nil :: Model?
CafeUpgradeService._plaqueLabel = nil :: TextLabel?

---> private

--- Resolves another Knit service. Indirection exists so specs can substitute fakes.
function CafeUpgradeService:_getService(name: string): any
	return Knit.GetService(name)
end

function CafeUpgradeService:_notify(player: Player, text: string)
	pcall(function()
		self:_getService("DialogService"):Notify(player, { Title = "Cafe Upgrade", Description = text, Text = text })
	end)
end

function CafeUpgradeService:_broadcast(text: string)
	for _, player in Players:GetPlayers() do
		self:_notify(player, text)
	end
end

function CafeUpgradeService:_isNearBoard(player: Player): boolean
	local board = self._board
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not board or not board.PrimaryPart or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - board.PrimaryPart.Position).Magnitude <= MAX_USE_DISTANCE
end

function CafeUpgradeService:_clearVisuals(id: string)
	for _, instance in self._visuals[id] or {} do
		instance:Destroy()
	end
	self._visuals[id] = {}
end

--- Rebuilds the models for one upgrade at its current level.
function CafeUpgradeService:_buildVisuals(id: string)
	local folder = self._folder
	if not folder then
		return
	end
	self:_clearVisuals(id)
	local level = self:GetLevel(id)
	if level < 1 then
		return
	end

	local origin = CafeUpgradeConfig.ORIGIN
	local placement = CafeUpgradeConfig.PLACEMENT
	local built: { Instance } = {}
	if id == "Plants" then
		local count = math.min(level * CafeUpgradeConfig.PLANTS_PER_LEVEL, #placement.Plants)
		for i = 1, count do
			table.insert(built, Builders.Plant(origin * placement.Plants[i], i))
		end
	elseif id == "Lights" then
		for i = 1, math.min(level, #placement.Lights) do
			local strand = placement.Lights[i]
			table.insert(
				built,
				Builders.LightStrand(origin:PointToWorldSpace(strand.From), origin:PointToWorldSpace(strand.To), i)
			)
		end
	end
	for _, instance in built do
		instance.Parent = folder
	end
	self._visuals[id] = built
end

function CafeUpgradeService:_refreshPlaque()
	local label = self._plaqueLabel
	if not label then
		return
	end
	local lines = CafeUpgradeConfig.PlaqueLines(self._contributions, CafeUpgradeConfig.PLAQUE_MAX_LINES)
	label.Text = if #lines == 0 then "Be the first to upgrade this cafe!" else table.concat(lines, "\n")
end

--- State only: records the new level and the contributor. No world or network side effects.
function CafeUpgradeService:_recordLevel(id: string, level: number, contributorName: string)
	local upgrade = CafeUpgradeConfig.GetUpgrade(id)
	self._levels[id] = level
	table.insert(self._contributions, {
		Name = contributorName,
		UpgradeName = if upgrade then upgrade.Name else id,
		Level = level,
	})
end

--- World and broadcast side effects after a level is recorded. Never throws.
function CafeUpgradeService:_onLevelApplied(id: string, level: number, player: Player)
	local okBuild, err = pcall(function()
		self:_buildVisuals(id)
	end)
	if not okBuild then
		warn(`[CafeUpgradeService] Failed to build {id} level {level}: {err}`)
	end
	self:_refreshPlaque()

	local upgrade = CafeUpgradeConfig.GetUpgrade(id)
	local name = if upgrade then upgrade.Name else id
	self:_broadcast(`{player.DisplayName} upgraded the cafe: {name} Lv {level}!`)

	pcall(function()
		local analytics = self:_getService("AnalyticsEvents")
		analytics:Custom(player, "CafeUpgradeBought", 1)
	end)
end

---> public

function CafeUpgradeService:GetLevel(id: string): number
	return self._levels[id] or 0
end

--[[
	Buys the next level of `upgradeId` for this server. Yields while the spend resolves.
	`expectedLevel` (optional) is the level the player saw in the menu; if someone else
	bought it first, nothing is spent. Returns `(true)` or `(false, reason)`.
]]
function CafeUpgradeService:TryPurchaseAsync(player: Player, upgradeId: any, expectedLevel: number?): (boolean, string?)
	local upgrade = CafeUpgradeConfig.GetUpgrade(upgradeId)
	if not upgrade then
		return false, "UnknownUpgrade"
	end
	local id = upgrade.Id
	local nextLevel, price = CafeUpgradeConfig.GetNextLevel(id, self:GetLevel(id))
	if not nextLevel or not price then
		return false, "Maxed"
	end
	if expectedLevel ~= nil and expectedLevel ~= nextLevel then
		return false, "Changed"
	end
	-- One purchase per upgrade at a time, so two buyers cannot both pay for the same level.
	if self._pending[id] then
		return false, "Busy"
	end

	self._pending[id] = true
	local okCall, spent, reason = pcall(function()
		return self:_getService("CurrencyService"):TrySpendAsync(player, "BobaBucks", price)
	end)
	self._pending[id] = nil

	if not okCall then
		warn(`[CafeUpgradeService] Spend failed for {player.Name}: {spent}`)
		return false, "Error"
	end
	if not spent then
		return false, reason or "SpendFailed"
	end

	self:_recordLevel(id, nextLevel, player.DisplayName)
	self:_onLevelApplied(id, nextLevel, player)
	return true
end

--- Server-driven menu: pick an upgrade, confirm, buy. One menu per player at a time.
function CafeUpgradeService:OpenMenu(player: Player)
	if self._busyPlayers[player] then
		return
	end
	self._busyPlayers[player] = true

	local ok, err = pcall(function()
		local dialogService = self:_getService("DialogService")

		local buttons = {}
		local labelToUpgrade: { [string]: CafeUpgradeConfig.Upgrade } = {}
		local seenLevel: { [string]: number } = {}
		for _, upgrade in CafeUpgradeConfig.UPGRADES do
			local level = self:GetLevel(upgrade.Id)
			local label = CafeUpgradeConfig.ButtonLabel(upgrade, level)
			local nextLevel = CafeUpgradeConfig.GetNextLevel(upgrade.Id, level)
			labelToUpgrade[label] = upgrade
			seenLevel[upgrade.Id] = level + 1
			table.insert(buttons, {
				Text = label,
				Color = Styles.GREEN_DIM,
				Disabled = nextLevel == nil,
			})
		end

		local okChoice, choice = dialogService
			:CreateDialog(player, "ActionPrompt", {
				Title = "Cafe Upgrades",
				Text = `Upgrades are shared by everyone in this server, and your name goes on the plaque!`,
				Buttons = buttons,
				CloseText = "Close",
			}, DIALOG_TIMEOUT_SECONDS)
			:await()
		if not okChoice or typeof(choice) ~= "string" or player.Parent == nil then
			return
		end
		local upgrade = labelToUpgrade[choice]
		if not upgrade then
			return
		end
		local nextLevel, price = CafeUpgradeConfig.GetNextLevel(upgrade.Id, seenLevel[upgrade.Id] - 1)
		if not nextLevel then
			return
		end

		local okConfirm, confirm = dialogService
			:CreateDialog(player, "ButtonPrompt", {
				Title = "Upgrade Cafe",
				Text = dialogService.FormatBrackets(
					`Add {upgrade.Name} Lv {nextLevel} for [{price} {CafeUpgradeConfig.CURRENCY_LABEL}]? {upgrade.Description}`
				),
				Buttons = {
					{ Text = "Buy", Color = Styles.GREEN },
					{ Text = "Cancel", Color = Styles.RED },
				},
			}, DIALOG_TIMEOUT_SECONDS)
			:await()
		if not okConfirm or confirm ~= "Buy" or player.Parent == nil then
			return
		end
		if not self:_isNearBoard(player) then
			self:_notify(player, "Walk back to the upgrade board to buy.")
			return
		end

		local bought, reason = self:TryPurchaseAsync(player, upgrade.Id, nextLevel)
		if bought then
			return
		end
		if reason == "InsufficientFunds" then
			-- Explicit Buy click just failed on funds: offer the Currency tab (server text only; client opens Shop).
			local dialogService = self:_getService("DialogService")
			local okFunds, fundsChoice = dialogService
				:CreateDialog(player, "ButtonPrompt", {
					Title = "Not enough Boba Bucks",
					Text = dialogService.FormatBrackets(`You need [{price} Boba Bucks] for that upgrade.`),
					Buttons = {
						{ Text = "Get Boba Bucks", Color = Styles.GREEN },
						{ Text = "Cancel", Color = Styles.RED },
					},
				}, DIALOG_TIMEOUT_SECONDS)
				:await()
			if okFunds and fundsChoice == "Get Boba Bucks" and player.Parent ~= nil then
				dialogService:OpenShop(player, "Currency")
			end
		elseif reason == "Changed" or reason == "Maxed" or reason == "Busy" then
			self:_notify(player, "Someone just bought that upgrade! Check the board again.")
		else
			self:_notify(player, "That upgrade didn't go through. Nothing was spent.")
		end
	end)
	self._busyPlayers[player] = nil
	if not ok then
		warn(`[CafeUpgradeService] Menu failed for {player.Name}: {err}`)
	end
end

---> lifecycle

function CafeUpgradeService:PlayerRemoving(player: Player)
	self._busyPlayers[player] = nil
end

function CafeUpgradeService:KnitStart()
	local existing = Workspace:FindFirstChild(CafeUpgradeConfig.FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = CafeUpgradeConfig.FOLDER_NAME
	folder:SetAttribute("BuiltBy", CafeUpgradeConfig.BUILT_BY)
	folder.Parent = Workspace
	self._folder = folder

	local board, prompt, label = Builders.Board(CafeUpgradeConfig.ORIGIN * CafeUpgradeConfig.PLACEMENT.Board)
	board.Parent = folder
	self._board = board
	self._plaqueLabel = label
	self:_refreshPlaque()

	prompt.Triggered:Connect(function(player: Player)
		task.spawn(function()
			self:OpenMenu(player)
		end)
	end)

	-- Any level recorded before start (none in a live server) gets its models now.
	for _, upgrade in CafeUpgradeConfig.UPGRADES do
		self:_buildVisuals(upgrade.Id)
	end
end

return CafeUpgradeService
