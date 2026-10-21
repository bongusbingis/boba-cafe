--[[
    Module: InteractionRunner
    Description: Runs recipe action sequences for players with per-player debouncing.
--]]

---> Requires

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

local KitchenTypes = require(ReplicatedStorage.Shared.Kitchen.KitchenTypes)
local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)

-- SoundService.SFX.Kitchen is authored in the place. It is looked up on use so a
-- missing folder only silences kitchen sounds instead of blocking server start.
local warnedMissingSounds = false
local function getKitchenSounds(): Instance?
	local sfx = SoundService:FindFirstChild("SFX")
	local kitchenSounds = sfx and sfx:FindFirstChild("Kitchen")
	if not kitchenSounds and not warnedMissingSounds then
		warnedMissingSounds = true
		warn("[InteractionRunner] SoundService.SFX.Kitchen not found; kitchen sounds are disabled.")
	end
	return kitchenSounds
end

-- The tool the player is holding, as the kitchen actions find it.
local function getHeldTool(player: Player): Tool?
	return player.Character and player.Character:FindFirstChildWhichIsA("Tool")
end

---> Types

type ActionData = KitchenTypes.ActionData
type RecipeData = KitchenTypes.RecipeData
type InteractionResult = KitchenTypes.InteractionResult

type ActionRegistry = {
	Get: (self: any, name: string) -> KitchenTypes.ActionFn?,
	Has: (self: any, name: string) -> boolean,
	Load: (self: any, folder: Folder) -> (),
}

type SequenceState = {
	PourDone: boolean?,
	PourTier: string?,
}

type InteractionRunner = {
	_debounces: { [Player]: boolean },
	_registry: ActionRegistry,
	_onFailure: (player: Player, reason: string) -> (),
	_onSuccess: ((player: Player, recipeData: RecipeData) -> ())?,
	_pourMoments: any?,
	Run: (self: InteractionRunner, player: Player, recipeData: RecipeData, model: Model) -> (),
	_runSequence: (
		self: InteractionRunner,
		player: Player,
		model: Model,
		actions: { ActionData },
		recipeData: RecipeData?,
		state: SequenceState?
	) -> InteractionResult,
	_runSelectFrom: (
		self: InteractionRunner,
		player: Player,
		model: Model,
		actionData: ActionData,
		recipeData: RecipeData?,
		state: SequenceState?
	) -> InteractionResult,
}

---> Module

local InteractionRunner = {}
InteractionRunner.__index = InteractionRunner

---> Constructor

function InteractionRunner.new(
	registry: ActionRegistry,
	onFailure: (player: Player, reason: string) -> (),
	onSuccessOrPours: any?,
	pourMoments: any?
): InteractionRunner
	local onSuccess = if typeof(onSuccessOrPours) == "function" then onSuccessOrPours else nil
	local pours = if typeof(onSuccessOrPours) == "table" and onSuccessOrPours.AwaitPour
		then onSuccessOrPours
		else pourMoments
	return setmetatable({
		_debounces = {},
		_registry = registry,
		_onFailure = onFailure,
		_onSuccess = onSuccess,
		_pourMoments = pours,
	}, InteractionRunner) :: any
end

---> Private

function InteractionRunner:_runSelectFrom(
	player: Player,
	model: Model,
	actionData: ActionData,
	recipeData: RecipeData?,
	state: SequenceState?
): InteractionResult
	local promptConfig = actionData[2] :: {
		Title: string?,
		Text: string?,
		Buttons: { { Text: string } }?,
		DialogType: string?,
		Items: { { Name: string, Model: Instance?, Color: Color3?, IsTip: boolean? } }?,
	}
	local branchMap = actionData[3] :: { [string]: { ActionData } }

	local DialogService = Knit.GetService("DialogService")
	local choice: string? = nil

	-- The tool held now is the one the station's gate just validated (nothing yields
	-- between the gate and here). The branch's actions apply to whatever is held when
	-- they run, so the dialog must not change it.
	local gatedTool = getHeldTool(player)

	if promptConfig.DialogType == "PromptSelection" then
		local promptItems = promptConfig.Items or {}
		local okPrompt, selectedIndex = DialogService:CreatePromptSelection(player, promptItems, {
			Title = promptConfig.Title,
			Text = promptConfig.Text,
		}):await()

		if not okPrompt or selectedIndex == nil then
			return { Success = true }
		end

		if typeof(selectedIndex) ~= "number" then
			warn(
				string.format("[InteractionRunner] PromptSelection returned invalid index: %s", tostring(selectedIndex))
			)
			return { Success = false, Error = "SelectFrom: invalid prompt selection" }
		end

		local selectedItem = promptItems[selectedIndex]
		if selectedItem and typeof(selectedItem.Name) == "string" and selectedItem.Name ~= "" then
			choice = selectedItem.Name
		elseif promptConfig.Buttons and promptConfig.Buttons[selectedIndex] then
			choice = promptConfig.Buttons[selectedIndex].Text
		end

		if not choice then
			warn(
				string.format("[InteractionRunner] PromptSelection: no option for index '%s'", tostring(selectedIndex))
			)
			return { Success = false, Error = "SelectFrom: missing prompt option" }
		end
	else
		local okPrompt, actionChoice = DialogService:CreateDialog(player, "ActionPrompt", promptConfig):await()

		if not okPrompt or actionChoice == nil or actionChoice == "Close" then
			return { Success = true }
		end

		if typeof(actionChoice) ~= "string" then
			warn(string.format("[InteractionRunner] ActionPrompt returned invalid choice: %s", tostring(actionChoice)))
			return { Success = false, Error = "SelectFrom: invalid choice" }
		end

		choice = actionChoice
	end

	if gatedTool ~= nil and getHeldTool(player) ~= gatedTool then
		-- Nothing in the branch has run, so there is nothing to undo.
		return { Success = false, Error = "SelectFrom: held tool changed" }
	end

	local branch = branchMap[choice]
	if not branch then
		warn(string.format("[InteractionRunner] SelectFrom: no branch for choice '%s'", tostring(choice)))
		return { Success = false, Error = "SelectFrom: invalid choice" }
	end

	return self:_runSequence(player, model, branch, recipeData, state)
end

function InteractionRunner:_runSequence(
	player: Player,
	model: Model,
	actions: { ActionData },
	recipeData: RecipeData?,
	state: SequenceState?
): InteractionResult
	local seqState = state or {}

	for _, actionData in actions do
		local actionName = actionData[1] :: string

		if actionName == "SelectFrom" then
			local result = self:_runSelectFrom(player, model, actionData, recipeData, seqState)
			if not result.Success then
				return result
			end
			continue
		end

		local isCheck = actionName == "ToolNameValidityCheck" or actionName == "ToolAttributeCheck"
		local isEmpty = actionName == "EmptyTool"

		-- If not a check or empty tool, and this recipe has a SkillMoment that hasn't run yet,
		-- invoke the pour moment before final actions!
		if not isCheck and not isEmpty and recipeData and recipeData.SkillMoment == true and not seqState.PourDone then
			seqState.PourDone = true
			if self._pourMoments and self._pourMoments.AwaitPour then
				local tier = self._pourMoments:AwaitPour(player, recipeData, model)
				if tier == nil then
					return { Success = false, Error = "Pour cancelled" }
				end
				seqState.PourTier = tier
			end
		end

		local actionFn = self._registry.Get(actionName)
		if not actionFn then
			warn(string.format("[InteractionRunner] Unknown action: '%s'", actionName))
			return { Success = false, Error = "Unknown action: " .. actionName }
		end

		local ok = actionFn(player, model, table.unpack(actionData, 2))
		if not ok then
			return { Success = false, Error = actionName .. " rejected" }
		end
	end

	return { Success = true }
end

---> Public

function InteractionRunner:Run(player: Player, recipeData: RecipeData, model: Model)
	if self._debounces[player] then
		return
	end

	self._debounces[player] = true

	task.spawn(function()
		-- An erroring action must not leave the player's debounce stuck forever.
		local ok, result = pcall(self._runSequence, self, player, model, recipeData.Actions, recipeData)
		if not ok then
			warn(string.format("[InteractionRunner] Interaction errored for %s: %s", player.Name, tostring(result)))
			result = { Success = false, Error = "Interaction error" }
		end

		if not result.Success then
			self._onFailure(player, result.Error :: string)
		else
			if recipeData.Sound then
				local kitchenSounds = getKitchenSounds()
				local soundTemplate = kitchenSounds and kitchenSounds:FindFirstChild(recipeData.Sound)
				local primaryPart = model.PrimaryPart
				if soundTemplate and primaryPart then
					local sound = soundTemplate:Clone()
					sound.Parent = primaryPart
					sound:Play()
					task.delay(soundTemplate.TimeLength, sound.Destroy, sound)
				end
			end
			-- A successful station may invoke onSuccess if provided.
			if self._onSuccess then
				local okSuccess, errSuccess = pcall(self._onSuccess, player, recipeData)
				if not okSuccess then
					warn(
						string.format(
							"[InteractionRunner] onSuccess failed for %s: %s",
							player.Name,
							tostring(errSuccess)
						)
					)
				end
			end
		end

		task.wait(KitchenConfig.INTERACTION_COOLDOWN)
		self._debounces[player] = nil
	end)
end

return InteractionRunner
