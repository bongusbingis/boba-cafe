--!strict
--[[
	Module: PassSettingsService
	Description: Pass perks that are switched with a Settings toggle (PASS-PORT lane C).
	             - Faster Walk Speed (perk "WalkSpeed", Settings.FasterWalkSpeed, default off):
	               WalkSpeed 32 instead of 16, reapplied on every respawn. Live game: 90%
	               boost described, 32 vs 16, toggled from the inventory.
	             - Uniform Remover (perk "UniformRemover", Settings.UniformRemoverEnabled,
	               default on for owners): UniformService leaves their own outfit alone.
	             - Headless Head (perk "HeadlessHead", Settings.HeadlessHead, default off):
	               Head and face decal transparency set to 1 on character.
	             Ownership comes from PerkService:HasPerk and is published as the player
	             attributes PerkWalkSpeed / PerkUniformRemover / PerkHeadlessHead so the Settings
	             page can gate its rows (catalog-only passes are not registered client side).
--]]

---> services

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local PassCatalog = require(Shared.Configuration.PassCatalog)

---> constants

local BASE_WALK_SPEED = 16
local BOOSTED_WALK_SPEED = 32
local WALK_SPEED_PERK = "WalkSpeed"
local UNIFORM_REMOVER_PERK = "UniformRemover"
local HEADLESS_HEAD_PERK = "HeadlessHead"
local WALK_SPEED_KEY = "FasterWalkSpeed"
local UNIFORM_REMOVER_KEY = "UniformRemoverEnabled"
local HEADLESS_HEAD_KEY = "HeadlessHead"
local HUMANOID_TIMEOUT_SECONDS = 10

---> service

local PassSettingsService = Knit.CreateService({
	Name = "PassSettingsService",
	Client = {},

	-- Fired (player) after a perk or one of its toggles changed.
	Changed = GoodSignal.new(),

	BASE_WALK_SPEED = BASE_WALK_SPEED,
	BOOSTED_WALK_SPEED = BOOSTED_WALK_SPEED,

	_owned = {} :: { [Player]: { [string]: boolean } },
	_settings = {} :: { [Player]: { [string]: any } },
})

---> private

function PassSettingsService:_getService(name: string): any
	return Knit.GetService(name)
end

function PassSettingsService:_publish(player: Player)
	local owned = self._owned[player] or {}
	player:SetAttribute("PerkWalkSpeed", owned[WALK_SPEED_PERK] == true)
	player:SetAttribute("PerkUniformRemover", owned[UNIFORM_REMOVER_PERK] == true)
	player:SetAttribute("PerkHeadlessHead", owned[HEADLESS_HEAD_PERK] == true)
end

function PassSettingsService:_loadOwnership(player: Player)
	local perks = self:_getService("PerkService")
	local owned = self._owned[player] or {}
	for _, perk in { WALK_SPEED_PERK, UNIFORM_REMOVER_PERK, HEADLESS_HEAD_PERK } do
		local ok, has = pcall(function()
			return perks:HasPerk(player, perk)
		end)
		owned[perk] = ok and has == true
	end
	if player.Parent == nil then
		return
	end
	self._owned[player] = owned
	self:_publish(player)
end

function PassSettingsService:_loadSettings(player: Player)
	local ok, success, data = pcall(function()
		return self:_getService("DataService"):GetDataAsync(player):await()
	end)
	local settingsTable = nil
	if ok and success and type(data) == "table" then
		if type(data.Settings) == "table" then
			settingsTable = data.Settings
		elseif type(data.Data) == "table" and type(data.Data.Settings) == "table" then
			settingsTable = data.Data.Settings
		end
	end
	local stored = if settingsTable ~= nil then settingsTable else {}
	if player.Parent == nil then
		return
	end
	self._settings[player] = table.clone(stored)
end

function PassSettingsService:_applySpeed(player: Player, character: Model?)
	local targetCharacter = character or player.Character
	if targetCharacter == nil then
		return
	end
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = targetCharacter:WaitForChild("Humanoid", HUMANOID_TIMEOUT_SECONDS) :: Humanoid?
	end
	if humanoid == nil or (player.Character ~= nil and player.Character ~= targetCharacter) then
		return
	end
	humanoid.WalkSpeed = if self:IsWalkSpeedActive(player) then BOOSTED_WALK_SPEED else BASE_WALK_SPEED
end

function PassSettingsService:_applyHeadless(player: Player, character: Model?)
	local targetCharacter = character or player.Character
	if targetCharacter == nil then
		return
	end
	local head = targetCharacter:FindFirstChild("Head")
	if head == nil then
		head = targetCharacter:WaitForChild("Head", HUMANOID_TIMEOUT_SECONDS) :: Instance?
	end
	if head == nil or not head:IsA("BasePart") or (player.Character ~= nil and player.Character ~= targetCharacter) then
		return
	end
	local isHeadless = self:IsHeadlessHeadActive(player)
	head.Transparency = if isHeadless then 1 else 0
	for _, child in head:GetChildren() do
		if child:IsA("Decal") and string.lower(child.Name) == "face" then
			child.Transparency = if isHeadless then 1 else 0
		end
	end
end

function PassSettingsService:_watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		self:_applySpeed(player, character)
		self:_applyHeadless(player, character)
		character.ChildAdded:Connect(function(child)
			if child.Name == "Head" then
				task.wait()
				self:_applyHeadless(player, character)
			end
		end)
	end)
	task.spawn(function()
		self:_loadOwnership(player)
		self:_loadSettings(player)
		self.Changed:Fire(player)
		self:_applySpeed(player)
		self:_applyHeadless(player)
	end)
end

---> public

function PassSettingsService:OwnsPerk(player: Player, perk: string): boolean
	local owned = self._owned[player]
	return owned ~= nil and owned[perk] == true
end

-- Owns Faster Walk Speed and has the toggle on (default off).
function PassSettingsService:IsWalkSpeedActive(player: Player): boolean
	local settings = self._settings[player]
	return self:OwnsPerk(player, WALK_SPEED_PERK) and settings ~= nil and settings[WALK_SPEED_KEY] == true
end

-- Owns Uniform Remover and has the toggle on (default on, so a fresh buyer keeps their outfit).
function PassSettingsService:IsUniformRemoverActive(player: Player): boolean
	local settings = self._settings[player]
	return self:OwnsPerk(player, UNIFORM_REMOVER_PERK)
		and not (settings ~= nil and settings[UNIFORM_REMOVER_KEY] == false)
end

-- Owns Headless Head and has the toggle on (default off).
function PassSettingsService:IsHeadlessHeadActive(player: Player): boolean
	local settings = self._settings[player]
	return self:OwnsPerk(player, HEADLESS_HEAD_PERK) and settings ~= nil and settings[HEADLESS_HEAD_KEY] == true
end

---> lifecycle

function PassSettingsService:KnitStart()
	self:_getService("SettingsService").SettingChanged:Connect(function(player: Player, key: string, value: any)
		if key ~= WALK_SPEED_KEY and key ~= UNIFORM_REMOVER_KEY and key ~= HEADLESS_HEAD_KEY then
			return
		end
		local settings = self._settings[player]
		if settings == nil then
			settings = {}
			self._settings[player] = settings
		end
		(settings :: { [string]: any })[key] = value
		if key == WALK_SPEED_KEY then
			self:_applySpeed(player)
		elseif key == HEADLESS_HEAD_KEY then
			self:_applyHeadless(player)
		end
		self.Changed:Fire(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			local entry = PassCatalog[passId]
			if not wasPurchased or entry == nil then
				return
			end
			if
				table.find(entry.Perks, WALK_SPEED_PERK) == nil
				and table.find(entry.Perks, UNIFORM_REMOVER_PERK) == nil
				and table.find(entry.Perks, HEADLESS_HEAD_PERK) == nil
			then
				return
			end
			(GamepassUtil :: any):GrantPassToCache(player, passId)
			self:_loadOwnership(player)
			self:_applySpeed(player)
			self:_applyHeadless(player)
			self.Changed:Fire(player)
		end
	)

	for _, player in Players:GetPlayers() do
		self:_watch(player)
	end
	Players.PlayerAdded:Connect(function(player)
		self:_watch(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._owned[player] = nil
		self._settings[player] = nil
	end)
end

return PassSettingsService
