--[[
    Module: KitchenService
    Description: Knit service that manages kitchen interaction prompts, action execution,
                 and the restocking system (legacy port).
--]]

---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Packages = ReplicatedStorage:WaitForChild("Packages")

---> Requires

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)
local ActionRegistry = require(script.ActionRegistry)
local InteractionRunner = require(script.InteractionRunner)
local PourMoments = require(script.PourMoments)
local PromptBuilder = require(script.PromptBuilder)
local Recipes = require(ReplicatedStorage.Shared.Kitchen.Recipes)
local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)
local KitchenTypes = require(ReplicatedStorage.Shared.Kitchen.KitchenTypes)
local WorldPath = require(ReplicatedStorage.Shared.Utility.WorldPath)

---> Types

type RecipeData = KitchenTypes.RecipeData

---> Constants

local WORLD_TIMEOUT_SECONDS = 10

---> Service

local KitchenService = Knit.CreateService({
	Name = "KitchenService",
	Client = {
		InteractionFailed = Knit.CreateSignal(),
		PourWindowOpened = Knit.CreateSignal(),
		PourResolved = Knit.CreateSignal(),
		SetBackpackEnabled = Knit.CreateSignal(),
	},
	_runner = nil :: any,
	_registry = nil :: any,
	_pours = nil :: any,
	_prompts = {} :: { [string]: { ProximityPrompt } },
	_modelPrompts = {} :: { [Model]: ProximityPrompt },
	_activeBoxTracks = {} :: { [Player]: AnimationTrack },
	_restockPromptShown = {} :: { [number]: boolean },
	_shiftService = nil :: any,
	StationRestocked = GoodSignal.new(),
})

---> Private Helper Functions

local function waitForKitchen(): Instance?
	local kitchen = WorldPath.waitFor(workspace, { "Assets", "Kitchen" }, WORLD_TIMEOUT_SECONDS)
	if not kitchen then
		warn("[KitchenService] workspace.Assets.Kitchen not found; kitchen stations are disabled.")
	end
	return kitchen
end

local function createBoxAccessory(): Accessory
	local box = Instance.new("Accessory")
	box.Name = "Box"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(2.57, 2.13, 2.14)
	handle.CanCollide = false
	handle.Anchored = false
	handle.Massless = true

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = KitchenConfig.RESTOCK_BOX_MESH_ID
	mesh.Parent = handle

	local att = Instance.new("Attachment")
	att.Name = "BodyFrontAttachment"
	att.Position = Vector3.new(-0.024, 0.157, -1.546)
	att.Parent = handle

	handle.Parent = box
	return box
end

local function updateSyrupVisual(model: Model, currentStock: number, defaultStock: number)
	local liquid = model:FindFirstChild("Liquid")
	if not liquid or not liquid:IsA("BasePart") then
		return
	end

	local originalCFrame = liquid:GetAttribute("OriginalCFrame") :: CFrame?
	local originalSize = liquid:GetAttribute("OriginalSize") :: Vector3?
	if not originalCFrame or not originalSize then
		liquid:SetAttribute("OriginalCFrame", liquid.CFrame)
		liquid:SetAttribute("OriginalSize", liquid.Size)
		originalCFrame = liquid.CFrame
		originalSize = liquid.Size
	end

	local fraction = math.clamp(currentStock / defaultStock, 0, 1)
	local newY = originalSize.Y * fraction
	local newSize = Vector3.new(originalSize.X, math.max(newY, 0.05), originalSize.Z)
	local offset = Vector3.new(0, (newY - originalSize.Y) / 2, 0)
	local newCFrame = originalCFrame * CFrame.new(offset)

	pcall(function()
		TweenService:Create(liquid, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = newSize,
			CFrame = newCFrame,
		}):Play()
	end)
end

local function updateTapiocaVisual(model: Model, currentStock: number, defaultStock: number)
	local liquidModel = model:FindFirstChild("Liquid")
	if not liquidModel then
		return
	end
	local pearls = liquidModel:GetChildren()
	if #pearls == 0 then
		return
	end

	local fraction = math.clamp(currentStock / defaultStock, 0, 1)
	local visibleCount = math.ceil(#pearls * fraction)
	for i, pearl in pearls do
		if pearl:IsA("BasePart") then
			pearl.Transparency = if i <= visibleCount then 0 else 1
		end
	end
end

local function updateDynamicVisual(model: Model, currentStock: number, defaultStock: number)
	local dynamicFolder = model:FindFirstChild("DynamicStock")
	if not dynamicFolder then
		return
	end
	local items = dynamicFolder:GetChildren()
	if #items == 0 then
		return
	end

	local fraction = math.clamp(currentStock / defaultStock, 0, 1)
	local visibleCount = math.ceil(#items * fraction)
	for i, item in items do
		local trans = if i <= visibleCount then 0 else 1
		if item:IsA("BasePart") then
			item.Transparency = trans
		elseif item:IsA("Model") then
			for _, part in item:GetDescendants() do
				if part:IsA("BasePart") then
					part.Transparency = trans
				end
			end
		end
	end
end

local function updateStationVisual(model: Model, currentStock: number, defaultStock: number)
	if string.find(model.Name, "Syrup") then
		updateSyrupVisual(model, currentStock, defaultStock)
	end
	if string.find(model.Name, "Tapioca") then
		updateTapiocaVisual(model, currentStock, defaultStock)
	end
	if model:FindFirstChild("DynamicStock") then
		updateDynamicVisual(model, currentStock, defaultStock)
	end
end

function KitchenService:_spawnSyrupDispensers(kitchen: Instance)
	local syrupsFolder = kitchen:FindFirstChild("Syrups")
	if not syrupsFolder then
		warn("[KitchenService] workspace.Assets.Kitchen.Syrups not found; syrup dispensers are disabled.")
		return
	end

	local template = WorldPath.find(ReplicatedStorage, { "SelectorModels", "Kitchen", "SyrupDispenser" })
	if not template then
		warn("[KitchenService] SelectorModels.Kitchen.SyrupDispenser not found; syrup dispensers are disabled.")
		return
	end

	local numSyrups = 0
	for _ in Recipes.Syrups do
		numSyrups += 1
	end

	for _, syrupsArea in syrupsFolder:GetChildren() do
		if not syrupsArea:IsA("BasePart") then
			continue
		end

		local n = 0
		for name: string, color: Color3 in Recipes.Syrups do
			n += 1
			local syrupDispenser = template:Clone()
			local dispenserPosition = ((syrupsArea.Size.X / (numSyrups + 1)) * n) - syrupsArea.Size.X / 2
			syrupDispenser:PivotTo(syrupsArea.CFrame * CFrame.new(dispenserPosition, 0, 0))
			syrupDispenser.Name = name .. " Syrup"
			syrupDispenser.Liquid.Color = color
			syrupDispenser.Rim.Color = color
			syrupDispenser.Parent = syrupsFolder
		end
	end
end

function KitchenService:_getMatchingModels(kitchen: Instance, itemName: string): { Model }
	local results = {}
	for _, descendant in kitchen:GetDescendants() do
		if descendant:IsA("Model") and descendant.Name == itemName then
			table.insert(results, descendant)
		end
	end
	return results
end

function KitchenService:_isClockedIn(player: Player): boolean
	local shiftService = self._shiftService
	return shiftService ~= nil and shiftService:IsClockedIn(player) == true
end

---> Public Restocking Methods

function KitchenService:GiveRestockBox(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if player:GetAttribute("Restocking") == true or character:FindFirstChild("Box") then
		return
	end

	local box = createBoxAccessory()
	humanoid:AddAccessory(box)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local anim = Instance.new("Animation")
		anim.AnimationId = KitchenConfig.RESTOCK_BOX_ANIMATION_ID
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		track:Play()
		self._activeBoxTracks[player] = track
	end

	player:SetAttribute("Restocking", true)
	self.Client.SetBackpackEnabled:Fire(player, false)

	if not self._restockPromptShown[player.UserId] then
		self._restockPromptShown[player.UserId] = true
		local ok, dialogService = pcall(function()
			return Knit.GetService("DialogService")
		end)
		if ok and dialogService and dialogService.Notify then
			dialogService:Notify(player, {
				Title = "Restocking Mode",
				Description = "You are now in Restocking mode. To get rid of your box, throw it away in a trash can.",
				Image = "",
				SoundEnabled = false,
			})
		end
	end
end

function KitchenService:ThrowAwayRestockBox(player: Player): boolean
	local character = player.Character
	if character then
		local box = character:FindFirstChild("Box")
		if box then
			box:Destroy()
		end
	end

	local track = self._activeBoxTracks[player]
	if track then
		pcall(function()
			track:Stop()
			track:Destroy()
		end)
		self._activeBoxTracks[player] = nil
	end

	player:SetAttribute("Restocking", nil)
	self.Client.SetBackpackEnabled:Fire(player, true)
	return true
end

function KitchenService:RestockStation(player: Player, model: Model, prompt: ProximityPrompt): boolean
	local currentStock = prompt:GetAttribute("CurrentStock") or 0
	local defaultStock = prompt:GetAttribute("DefaultStock") or KitchenConfig.GetDefaultStock(model.Name)

	if currentStock >= defaultStock then
		local ok, dialogService = pcall(function()
			return Knit.GetService("DialogService")
		end)
		if ok and dialogService and dialogService.Notify then
			dialogService:Notify(player, {
				Title = "Restock",
				Description = "This station is already fully stocked!",
				Image = "",
				SoundEnabled = false,
			})
		end
		return false
	end

	-- Replenish stock to maximum
	prompt:SetAttribute("CurrentStock", defaultStock)
	updateStationVisual(model, defaultStock, defaultStock)

	-- Destroy the carried restock box
	self:ThrowAwayRestockBox(player)

	-- Award XP (Points are retired; Jack directive)
	pcall(function()
		local progressionService = Knit.GetService("ProgressionService")
		if progressionService and progressionService.AddXp then
			progressionService:AddXp(player, KitchenConfig.RESTOCK_XP_AWARD)
		end
	end)

	-- Play audio SFX/UI/Serve (Jack directive)
	pcall(function()
		local sfx = SoundService:FindFirstChild("SFX")
		local ui = sfx and sfx:FindFirstChild("UI")
		local serveSound = ui and ui:FindFirstChild("Serve")
		if serveSound and serveSound:IsA("Sound") then
			serveSound:Play()
		end
	end)

	self.StationRestocked:Fire(player, model)

	return true
end

function KitchenService:_wireRestockingShelves(kitchen: Instance)
	local givers = kitchen:FindFirstChild("Givers")
	if not givers then
		return
	end

	for _, model in givers:GetChildren() do
		if model.Name == "Restocking" and model:IsA("Model") then
			PromptBuilder.Attach(model, {
				Label = "Restocking",
				ActionText = "Grab Box",
				HoldDuration = KitchenConfig.RESTOCK_HOLD_DURATION,
				MaxActivationDistance = 10,
			}, function(player: Player)
				if not self:_isClockedIn(player) then
					self.Client.InteractionFailed:Fire(player, "ClockedOut")
					return
				end
				if player:GetAttribute("Restocking") == true then
					return
				end
				self:GiveRestockBox(player)
			end)
		end
	end
end

---> Lifecycle

function KitchenService:KnitInit()
	local registry = ActionRegistry
	registry.Load(script.Actions)
	self._registry = registry

	self._pours = PourMoments.new(self)
	self._runner = InteractionRunner.new(registry, function(player: Player, reason: string)
		self.Client.InteractionFailed:Fire(player, reason)
	end, function(player: Player, _recipeData: RecipeData, model: Model)
		-- Station interaction succeeded: decrement stock if applicable
		local prompt = self._modelPrompts[model] or model:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			local currentStock = prompt:GetAttribute("CurrentStock")
			local defaultStock = prompt:GetAttribute("DefaultStock") or KitchenConfig.GetDefaultStock(model.Name)
			if currentStock ~= nil then
				local okPerk, perkService = pcall(function()
					return Knit.GetService("PerkService")
				end)
				local hasUnlimited = okPerk
					and perkService ~= nil
					and perkService:HasPerk(player, "UnlimitedStock") == true
				if not hasUnlimited then
					local newStock = math.max(0, currentStock - 1)
					prompt:SetAttribute("CurrentStock", newStock)
					updateStationVisual(model, newStock, defaultStock)
				end
			end
		end
	end, self._pours)
end

function KitchenService:KnitStart()
	self._shiftService = Knit.GetService("ShiftService")
	self._pours:Start()

	local kitchen = waitForKitchen()
	if not kitchen then
		return
	end

	self:_spawnSyrupDispensers(kitchen)
	self:_wireRestockingShelves(kitchen)

	for itemName, recipeData: RecipeData in Recipes.Items do
		local models = self:_getMatchingModels(kitchen, itemName)
		self._prompts[itemName] = {}

		local stockCapacity = KitchenConfig.GetDefaultStock(itemName)

		for _, model in models do
			local prompt: ProximityPrompt
			prompt = PromptBuilder.Attach(model, {
				Label = itemName,
				ActionText = "Interact",
				HoldDuration = recipeData.HoldDuration,
				Stock = stockCapacity,
				Theme = "Restock",
			}, function(player: Player)
				if not self:_isClockedIn(player) then
					self.Client.InteractionFailed:Fire(player, "ClockedOut")
					return
				end

				local targetPrompt = prompt
					or self._modelPrompts[model]
					or model:FindFirstChildWhichIsA("ProximityPrompt", true)

				-- If player is carrying a restock box, restock the station:
				if player:GetAttribute("Restocking") == true then
					if targetPrompt then
						self:RestockStation(player, model, targetPrompt)
					end
					return
				end

				-- Normal drink preparation: verify station has stock
				local currentStock = targetPrompt and targetPrompt:GetAttribute("CurrentStock")
				if currentStock ~= nil and currentStock <= 0 then
					local okPerk, perkService = pcall(function()
						return Knit.GetService("PerkService")
					end)
					local hasUnlimited = okPerk
						and perkService ~= nil
						and perkService:HasPerk(player, "UnlimitedStock") == true
					if not hasUnlimited then
						self.Client.InteractionFailed:Fire(player, "OutOfStock")
						return
					end
				end

				local primaryPart = model.PrimaryPart
				if not primaryPart then
					return
				end

				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if not rootPart then
					return
				end

				local distance = (rootPart.Position - primaryPart.Position).Magnitude
				if distance > KitchenConfig.MAX_INTERACTION_DISTANCE then
					return
				end

				self._runner:Run(player, recipeData, model)
			end)

			self._modelPrompts[model] = prompt
			table.insert(self._prompts[itemName], prompt)
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		self._activeBoxTracks[player] = nil
		self._restockPromptShown[player.UserId] = nil
	end)
end

---> Public

function KitchenService:SetItemEnabled(itemName: string, enabled: boolean)
	local prompts = self._prompts[itemName]
	if not prompts then
		return
	end

	for _, prompt in prompts do
		prompt.Enabled = enabled
	end
end

function KitchenService.Client:ReportPourTap(player: Player, windowId: number, claimedElapsed: number): any
	return self.Server:ReportPourTap(player, windowId, claimedElapsed)
end

function KitchenService:ReportPourTap(player: Player, windowId: number, claimedElapsed: number): any
	return self._pours:ReportTap(player, windowId, claimedElapsed)
end

function KitchenService:GetPourTip(tools: { Instance }): number
	return self._pours:TipForTools(tools)
end

return KitchenService
