--!strict
--[[
	CharacterCustomizationService
	Server service managing player uniform choices, costume ownership, and live character welding.
	Implements clock-in uniform mandates and BobaCostume wearable welding.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local STAR_EMPLOYEE_PASS_ID = 219650999

type CharacterCustomizationData = {
	EquippedUniform: string?,
	OwnedCostumes: { [string]: boolean },
	EquippedCostume: string?,
}

local CharacterCustomizationService = Knit.CreateService({
	Name = "CharacterCustomizationService",
	Client = {
		CharacterCustomizationChanged = Knit.CreateSignal(),
	},
	_shift = nil :: any,
	_uniformService = nil :: any,
})

local function getPlayerData(player: Player): any
	local ok, dataService = pcall(function()
		return Knit.GetService("DataService")
	end)
	if not ok or not dataService then
		return nil
	end

	if typeof((dataService :: any).GetDataAsync) == "function" then
		local dataOk, res1, res2 = pcall(function()
			local promise = (dataService :: any):GetDataAsync(player)
			if promise and typeof(promise.timeout) == "function" then
				return promise:timeout(5):await()
			elseif promise and typeof(promise.await) == "function" then
				return promise:await()
			else
				return true, promise
			end
		end)
		if dataOk then
			local success = res1
			local data = res2
			if success == true and data ~= nil then
				return data
			elseif success ~= false and res1 ~= nil then
				return res1
			end
		end
	end

	if typeof((dataService :: any).GetProfile) == "function" then
		local profOk, prof = pcall(function()
			return (dataService :: any):GetProfile(player)
		end)
		if profOk and prof then
			return prof
		end
	end

	return nil
end

local function getCharacterBlock(playerData: any): any?
	if not playerData then
		return nil
	end
	if playerData.Character ~= nil and typeof(playerData.Character) == "table" then
		return playerData.Character
	elseif playerData.Data ~= nil and typeof(playerData.Data) == "table" and playerData.Data.Character ~= nil then
		return playerData.Data.Character
	end
	return nil
end

local function ensureCharacterBlock(playerData: any): any
	local targetTable = if playerData.Data ~= nil and typeof(playerData.Data) == "table"
		then playerData.Data
		else playerData

	if not targetTable.Character or typeof(targetTable.Character) ~= "table" then
		targetTable.Character = {
			EquippedUniform = "Default",
			OwnedCostumes = {},
			EquippedCostume = nil,
		}
	end
	return targetTable.Character
end

local function getCostumeTemplate(costumeId: string): Model?
	local sharedStorage = ReplicatedStorage:FindFirstChild("SharedStorage")
	local npcs = sharedStorage and sharedStorage:FindFirstChild("NPCs")
	local buddy = npcs and npcs:FindFirstChild("BobaBuddy")
	if buddy then
		local costume = buddy:FindFirstChild(costumeId) or buddy:FindFirstChild("BobaCostume")
		if costume and costume:IsA("Model") then
			return costume
		end
	end
	return nil
end

function CharacterCustomizationService:_applyCostume(player: Player, costumeId: string)
	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	self:_removeCostume(player)

	local template = getCostumeTemplate(costumeId)
	if not template then
		return
	end

	local buddy = template.Parent
	local templateHrp = buddy and buddy:FindFirstChild("HumanoidRootPart") :: BasePart?

	local costumeClone = template:Clone()
	costumeClone.Name = "EquippedCostume"

	-- Remove scripts inside costume for safety
	for _, child in costumeClone:GetDescendants() do
		if child:IsA("LuaSourceContainer") then
			child:Destroy()
		end
	end

	-- Weld parts
	for _, part in costumeClone:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			part.Anchored = false

			if templateHrp then
				local rel = templateHrp.CFrame:ToObjectSpace(part.CFrame)
				part.CFrame = hrp.CFrame:ToWorldSpace(rel)
			end

			local weld = Instance.new("WeldConstraint")
			weld.Name = `{part.Name}Weld`
			weld.Part0 = hrp
			weld.Part1 = part
			weld.Parent = part
		end
	end

	costumeClone.Parent = character
end

function CharacterCustomizationService:_removeCostume(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local existing = character:FindFirstChild("EquippedCostume")
	if existing then
		existing:Destroy()
	end
end

function CharacterCustomizationService:GetCharacterState(player: Player): CharacterCustomizationData
	local playerData = getPlayerData(player)
	local charData = getCharacterBlock(playerData)
	if charData then
		return {
			EquippedUniform = charData.EquippedUniform,
			OwnedCostumes = charData.OwnedCostumes or {},
			EquippedCostume = charData.EquippedCostume,
		}
	end
	return {
		EquippedUniform = "Default",
		OwnedCostumes = {},
		EquippedCostume = nil,
	}
end

function CharacterCustomizationService:GetEquippedUniform(player: Player): string?
	local state = self:GetCharacterState(player)
	return state.EquippedUniform
end

function CharacterCustomizationService:EquipUniform(player: Player, uniformId: string?): (boolean, string?)
	local playerData = getPlayerData(player)
	if not playerData then
		return false, "DataNotLoaded"
	end

	local isClockedIn = self._shift and self._shift:IsClockedIn(player)

	-- Clock-in mandate: must always wear a uniform while clocked in
	if isClockedIn and (uniformId == nil or uniformId == "") then
		return false, "UniformMandatoryWhileClockedIn"
	end

	if uniformId == "StarEmployee" then
		local owns = false
		local okPass, result = pcall(function()
			return (GamepassUtil :: any):PlayerOwnsPassAsync(player, STAR_EMPLOYEE_PASS_ID)
		end)
		if okPass and result == true then
			owns = true
		end
		if not owns then
			return false, "GamepassRequired"
		end
	end

	local charData = ensureCharacterBlock(playerData)
	charData.EquippedUniform = uniformId

	if self._uniformService and self._uniformService._apply then
		if uniformId == nil then
			self._uniformService:_restore(player)
		else
			self._uniformService:_apply(player)
		end
	end

	local state = self:GetCharacterState(player)
	self.Client.CharacterCustomizationChanged:Fire(player, state)
	return true, nil
end

function CharacterCustomizationService:EquipCostume(player: Player, costumeId: string?): (boolean, string?)
	local playerData = getPlayerData(player)
	if not playerData then
		return false, "DataNotLoaded"
	end

	local charData = ensureCharacterBlock(playerData)

	if costumeId ~= nil and costumeId ~= "" then
		local owned = charData.OwnedCostumes and charData.OwnedCostumes[costumeId]
		if not owned then
			return false, "CostumeNotOwned"
		end
		charData.EquippedCostume = costumeId
		self:_applyCostume(player, costumeId)
	else
		charData.EquippedCostume = nil
		self:_removeCostume(player)
	end

	local state = self:GetCharacterState(player)
	self.Client.CharacterCustomizationChanged:Fire(player, state)
	return true, nil
end

function CharacterCustomizationService:GrantCostume(player: Player, costumeId: string): (boolean, string?)
	local playerData = getPlayerData(player)
	if not playerData then
		return false, "DataNotLoaded"
	end

	local charData = ensureCharacterBlock(playerData)
	if not charData.OwnedCostumes then
		charData.OwnedCostumes = {}
	end

	charData.OwnedCostumes[costumeId] = true

	local state = self:GetCharacterState(player)
	self.Client.CharacterCustomizationChanged:Fire(player, state)
	return true, nil
end

function CharacterCustomizationService.Client:GetCharacterState(player: Player): CharacterCustomizationData
	return self.Server:GetCharacterState(player)
end

function CharacterCustomizationService.Client:EquipUniform(player: Player, uniformId: string?): (boolean, string?)
	return self.Server:EquipUniform(player, uniformId)
end

function CharacterCustomizationService.Client:EquipCostume(player: Player, costumeId: string?): (boolean, string?)
	return self.Server:EquipCostume(player, costumeId)
end

function CharacterCustomizationService:KnitInit()
	-- Initialization
end

function CharacterCustomizationService:KnitStart()
	self._shift = Knit.GetService("ShiftService")
	self._uniformService = Knit.GetService("UniformService")

	-- Enforce clock-in uniform mandate
	if self._shift and self._shift.ClockedInChanged then
		self._shift.ClockedInChanged:Connect(function(player: Player, clockedIn: boolean)
			if clockedIn then
				local state = self:GetCharacterState(player)
				if state.EquippedUniform == nil then
					local ownsStar = false
					local okPass, res = pcall(function()
						return (GamepassUtil :: any):PlayerOwnsPassAsync(player, STAR_EMPLOYEE_PASS_ID)
					end)
					if okPass and res == true then
						ownsStar = true
					end
					local autoUniform = if ownsStar then "StarEmployee" else "Default"
					self:EquipUniform(player, autoUniform)
				end
			end
		end)
	end

	-- Re-apply costume on character respawn
	local function onCharacterLoaded(player: Player, _char: Model)
		local state = self:GetCharacterState(player)
		if state.EquippedCostume ~= nil then
			task.defer(function()
				self:_applyCostume(player, state.EquippedCostume :: string)
			end)
		end
	end

	local function watchPlayer(player: Player)
		player.CharacterAppearanceLoaded:Connect(function(char)
			onCharacterLoaded(player, char)
		end)
		if player.Character then
			onCharacterLoaded(player, player.Character)
		end
	end

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return CharacterCustomizationService
