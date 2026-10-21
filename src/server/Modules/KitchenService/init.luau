--[[
    Module: KitchenService
    Description: Knit service that manages kitchen interaction prompts and action execution.
--]]

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

---> Requires

local Knit = require(Packages.Knit)
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
		-- BIG-B7 skill moment: server -> client with the meter view to draw,
		-- then server -> client with (windowId, perfect) after a tap.
		PourWindowOpened = Knit.CreateSignal(),
		PourResolved = Knit.CreateSignal(),
	},
	_runner = nil :: any,
	_registry = nil :: any,
	_pours = nil :: any,
	_prompts = {} :: { [string]: { ProximityPrompt } },
	_shiftService = nil :: any,
})

---> Private

-- Waits (bounded) for workspace.Assets.Kitchen. Returns nil when it is missing.
local function waitForKitchen(): Instance?
	local kitchen = WorldPath.waitFor(workspace, { "Assets", "Kitchen" }, WORLD_TIMEOUT_SECONDS)
	if not kitchen then
		warn("[KitchenService] workspace.Assets.Kitchen not found; kitchen stations are disabled.")
	end
	return kitchen
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

-- Kitchen stations are for baristas, which means clocked-in players (ShiftService).
function KitchenService:_isClockedIn(player: Player): boolean
	local shiftService = self._shiftService
	return shiftService ~= nil and shiftService:IsClockedIn(player) == true
end

---> Lifecycle

function KitchenService:KnitInit()
	local registry = ActionRegistry
	registry.Load(script.Actions)
	self._registry = registry

	self._pours = PourMoments.new(self)
	self._runner = InteractionRunner.new(registry, function(player: Player, reason: string)
		self.Client.InteractionFailed:Fire(player, reason)
	end, nil, self._pours)
end

function KitchenService:KnitStart()
	self._shiftService = Knit.GetService("ShiftService")
	self._pours:Start()

	local kitchen = waitForKitchen()
	if not kitchen then
		return
	end

	self:_spawnSyrupDispensers(kitchen)

	for itemName, recipeData: RecipeData in Recipes.Items do
		local models = self:_getMatchingModels(kitchen, itemName)
		self._prompts[itemName] = {}

		for _, model in models do
			local prompt = PromptBuilder.Attach(
				model,
				{ Label = itemName, ActionText = "Interact", HoldDuration = recipeData.HoldDuration },
				function(player: Player)
					if not self:_isClockedIn(player) then
						-- The client shows a Clock In toast (KitchenController).
						self.Client.InteractionFailed:Fire(player, "ClockedOut")
						return
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
				end
			)

			table.insert(self._prompts[itemName], prompt)
		end
	end
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

-- BIG-B7 skill moment: the client reports its tap; the server grades it with
-- the shared PourMeter logic (the server owns the clock) and marks the held
-- drink's PerfectPours attribute on a perfect tap. Missing windows grade false.
function KitchenService.Client:ReportPourTap(player: Player, windowId: number, claimedElapsed: number): any
	return self.Server:ReportPourTap(player, windowId, claimedElapsed)
end

function KitchenService:ReportPourTap(player: Player, windowId: number, claimedElapsed: number): any
	return self._pours:ReportTap(player, windowId, claimedElapsed)
end

-- BIG-B7 skill moment: the flat BobaBuck tip for a set of served tools. The
-- serve lane adds this to the payout before it destroys the tools.
function KitchenService:GetPourTip(tools: { Instance }): number
	return self._pours:TipForTools(tools)
end

return KitchenService
