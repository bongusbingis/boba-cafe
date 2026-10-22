--!strict
--[[
	Module: PassSettingsService
	Description: Pass perks that are switched with a Settings toggle (PASS-PORT lane C).
	             - Faster Walk Speed (perk "WalkSpeed", Settings.FasterWalkSpeed, default off):
	               WalkSpeed 32 instead of 16, reapplied on every respawn. Live game: 90%
	               boost described, 32 vs 16, toggled from the inventory.
	             - Uniform Remover (perk "UniformRemover", Settings.UniformRemoverEnabled,
	               default on for owners): UniformService leaves their own outfit alone.
	             Ownership comes from PerkService:HasPerk and is published as the player
	             attributes PerkWalkSpeed / PerkUniformRemover so the Settings page can gate
	             its rows (catalog-only passes are not registered client side).
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
local WALK_SPEED_KEY = "FasterWalkSpeed"
local UNIFORM_REMOVER_KEY = "UniformRemoverEnabled"
local HUMANOID_TIMEOUT_SECONDS = 10

---> service

local PassSettingsService = Knit.CreateService({
	Name = "PassSettingsService",
	Client = {},

	-- Fired (player) after a perk or one of its toggles changed.
	Changed = GoodSignal.new(),

	_owned = {} :: { [Player]: { [string]: boolean } },
	_settings = {} :: { [Player]: { [string]: any } },
})

---> private

function PassSettingsService:_publish(player: Player)
	local owned = self._owned[player] or {}
	player:SetAttribute("PerkWalkSpeed", owned[WALK_SPEED_PERK] == true)
	player:SetAttribute("PerkUniformRemover", owned[UNIFORM_REMOVER_PERK] == true)
end

function PassSettingsService:_loadOwnership(player: Player)
	local perks = Knit.GetService("PerkService")
	local owned = self._owned[player] or {}
	for _, perk in { WALK_SPEED_PERK, UNIFORM_REMOVER_PERK } do
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
	local ok, data = pcall(function()
		return Knit.GetService("DataService"):GetDataAsync(player):await()
	end)
	local stored = if ok and type(data) == "table" and type(data.Settings) == "table" then data.Settings else {}
	if player.Parent == nil then
		return
	end
	self._settings[player] = table.clone(stored)
end

function PassSettingsService:_applySpeed(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		humanoid = character:WaitForChild("Humanoid", HUMANOID_TIMEOUT_SECONDS) :: Humanoid?
	end
	if humanoid == nil or player.Character ~= character then
		return
	end
	humanoid.WalkSpeed = if self:IsWalkSpeedActive(player) then BOOSTED_WALK_SPEED else BASE_WALK_SPEED
end

function PassSettingsService:_watch(player: Player)
	player.CharacterAdded:Connect(function()
		self:_applySpeed(player)
	end)
	task.spawn(function()
		self:_loadOwnership(player)
		self:_loadSettings(player)
		self.Changed:Fire(player)
		self:_applySpeed(player)
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

---> lifecycle

function PassSettingsService:KnitStart()
	Knit.GetService("SettingsService").SettingChanged:Connect(function(player: Player, key: string, value: any)
		if key ~= WALK_SPEED_KEY and key ~= UNIFORM_REMOVER_KEY then
			return
		end
		local settings = self._settings[player]
		if settings == nil then
			settings = {}
			self._settings[player] = settings
		end
		(settings :: { [string]: any })[key] = value
		self:_applySpeed(player)
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
			then
				return
			end
			(GamepassUtil :: any):GrantPassToCache(player, passId)
			self:_loadOwnership(player)
			self:_applySpeed(player)
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
