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
	local dataService = Knit.GetService("DataService")
	if not dataService then
		return nil
	end
	return dataService:GetProfile(player)
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

	-- Remove existing costume if present
	local existing = character:FindFirstChild("BobaCostume")
	if existing then
		existing:Destroy()
	end

	local template = getCostumeTemplate(costumeId)
	if not template then
		return
	end

	local costume = template:Clone()
	costume.Name = "BobaCostume"

	-- Remove any client scripts or conflicting objects inside the cloned costume
	local costumeWeldScript = costume:FindFirstChild("CostumeWeld")
	if costumeWeldScript then
		costumeWeldScript:Destroy()
	end

	-- Find template HumanoidRootPart to compute relative offsets
	local templateRig = template.Parent :: Model?
	local templateHrp = templateRig and templateRig:FindFirstChild("HumanoidRootPart") :: BasePart?
	local templateRefCF = if templateHrp then templateHrp.CFrame else costume:GetPivot()

	-- Position and weld each part to player's HumanoidRootPart
	for _, desc in costume:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.CanCollide = false
			desc.Massless = true
			desc.Anchored = false

			local relCF = templateRefCF:ToObjectSpace(desc.CFrame)
			desc.CFrame = hrp.CFrame:ToWorldSpace(relCF)

			local weld = desc:FindFirstChildOfClass("WeldConstraint")
			if not weld then
				weld = Instance.new("WeldConstraint")
				weld.Name = `{desc.Name}Weld`
				weld.Part0 = hrp
				weld.Part1 = desc
				weld.Parent = desc
			else
				weld.Part0 = hrp
				weld.Part1 = desc
			end
		end
	end

	costume.Parent = character
end

function CharacterCustomizationService:_removeCostume(player: Player)
	local character = player.Character
	if character then
		local existing = character:FindFirstChild("BobaCostume")
		if existing then
			existing:Destroy()
		end
	end
end

function CharacterCustomizationService:GetCharacterState(player: Player): CharacterCustomizationData
	local profile = getPlayerData(player)
	if profile and profile.Data and profile.Data.Character then
		local charData = profile.Data.Character
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
	local profile = getPlayerData(player)
	if not profile or not profile.Data then
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

	if not profile.Data.Character then
		profile.Data.Character = {
			EquippedUniform = "Default",
			OwnedCostumes = {},
			EquippedCostume = nil,
		}
	end

	profile.Data.Character.EquippedUniform = uniformId

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
	local profile = getPlayerData(player)
	if not profile or not profile.Data then
		return false, "DataNotLoaded"
	end

	if not profile.Data.Character then
		profile.Data.Character = {
			EquippedUniform = "Default",
			OwnedCostumes = {},
			EquippedCostume = nil,
		}
	end

	if costumeId ~= nil and costumeId ~= "" then
		local owned = profile.Data.Character.OwnedCostumes and profile.Data.Character.OwnedCostumes[costumeId]
		if not owned then
			return false, "CostumeNotOwned"
		end
		profile.Data.Character.EquippedCostume = costumeId
		self:_applyCostume(player, costumeId)
	else
		profile.Data.Character.EquippedCostume = nil
		self:_removeCostume(player)
	end

	local state = self:GetCharacterState(player)
	self.Client.CharacterCustomizationChanged:Fire(player, state)
	return true, nil
end

function CharacterCustomizationService:GrantCostume(player: Player, costumeId: string): (boolean, string?)
	local profile = getPlayerData(player)
	if not profile or not profile.Data then
		return false, "DataNotLoaded"
	end

	if not profile.Data.Character then
		profile.Data.Character = {
			EquippedUniform = "Default",
			OwnedCostumes = {},
			EquippedCostume = nil,
		}
	end

	if not profile.Data.Character.OwnedCostumes then
		profile.Data.Character.OwnedCostumes = {}
	end

	profile.Data.Character.OwnedCostumes[costumeId] = true

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
