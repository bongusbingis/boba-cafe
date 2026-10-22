--!strict
--[[
    Module: UniformService
    Description: Clocked-in baristas wear the cafe uniform (REVIVAL-001 NPC-LOOK).
                 Default is ReplicatedStorage.SharedStorage.Uniforms.Default.
                 Star Employee gamepass owners wear ReplicatedStorage.SharedStorage.Uniforms.StarEmployee.
                 On clock-in the character's Shirt/Pants templates are recorded and set
                 to the appropriate uniform; on clock-out they are restored. A missing
                 uniform asset warns once and skips.
--]]

---> services

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies

local Knit = require(Packages.Knit)
local WorldPath = require(Shared.Utility.WorldPath)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

---> types

type Saved = {
	Shirt: string?, -- original template; nil when the instance did not exist
	Pants: string?,
	CreatedShirt: boolean,
	CreatedPants: boolean,
}

---> constants

local ASSET_TIMEOUT_SECONDS = 5
local STAR_EMPLOYEE_PASS_ID = 219650999

---> service

local UniformService = Knit.CreateService({
	Name = "UniformService",
	Client = {},

	_saved = {} :: { [Player]: Saved },
	_warned = {} :: { [string]: boolean },
})

---> private

function UniformService:_warnOnce(message: string)
	if not self._warned[message] then
		self._warned[message] = true
		warn(`[UniformService] {message}`)
	end
end

-- The template string of a Shirt/Pants asset, or nil (warns once).
function UniformService:_template(folderName: string, pieceName: "Shirt" | "Pants"): string?
	local asset = WorldPath.find(ReplicatedStorage, { "SharedStorage", "Uniforms", folderName, pieceName })
	if asset == nil then
		asset = WorldPath.waitFor(
			ReplicatedStorage,
			{ "SharedStorage", "Uniforms", folderName, pieceName },
			ASSET_TIMEOUT_SECONDS
		)
	end
	if asset == nil or not asset:IsA(pieceName) then
		self:_warnOnce(
			`ReplicatedStorage.SharedStorage.Uniforms.{folderName}.{pieceName} is missing; no uniform for that piece.`
		)
		return nil
	end
	return if pieceName == "Shirt" then (asset :: Shirt).ShirtTemplate else (asset :: Pants).PantsTemplate
end

-- True when the player owns Uniform Remover and has the "Keep My Outfit" toggle on.
function UniformService:_keepsOwnOutfit(player: Player): boolean
	local passSettings = self._passSettings
	if passSettings == nil then
		return false
	end
	local ok, keeps = pcall(function()
		return passSettings:IsUniformRemoverActive(player)
	end)
	return ok and keeps == true
end

function UniformService:_apply(player: Player)
	pcall(function()
		local character = player.Character
		if character == nil or not self._shift:IsClockedIn(player) then
			return
		end

		-- Uniform Remover owners with the toggle on keep their own outfit.
		if self:_keepsOwnOutfit(player) then
			return
		end

		local ownsStarEmployee = false
		local okPass, owns = pcall(function()
			return (GamepassUtil :: any):PlayerOwnsPassAsync(player, STAR_EMPLOYEE_PASS_ID)
		end)
		if okPass and owns == true then
			ownsStarEmployee = true
		end

		local folderName = if ownsStarEmployee then "StarEmployee" else "Default"
		local shirtTemplate = self:_template(folderName, "Shirt")
		local pantsTemplate = self:_template(folderName, "Pants")

		-- The yield above can outlive the clock-in or the character.
		if player.Character ~= character or not self._shift:IsClockedIn(player) then
			return
		end

		local saved = self._saved[player]
		if saved == nil then
			saved = { CreatedShirt = false, CreatedPants = false }
			self._saved[player] = saved
		end
		local record = saved :: Saved

		if shirtTemplate ~= nil then
			local shirt = character:FindFirstChildOfClass("Shirt")
			if shirt == nil then
				shirt = Instance.new("Shirt")
				shirt.Parent = character
				record.CreatedShirt = true
			elseif record.Shirt == nil and not record.CreatedShirt then
				record.Shirt = (shirt :: Shirt).ShirtTemplate
			end
			(shirt :: Shirt).ShirtTemplate = shirtTemplate
		end
		if pantsTemplate ~= nil then
			local pants = character:FindFirstChildOfClass("Pants")
			if pants == nil then
				pants = Instance.new("Pants")
				pants.Parent = character
				record.CreatedPants = true
			elseif record.Pants == nil and not record.CreatedPants then
				record.Pants = (pants :: Pants).PantsTemplate
			end
			(pants :: Pants).PantsTemplate = pantsTemplate
		end
	end)
end

function UniformService:_restore(player: Player)
	local record = self._saved[player]
	self._saved[player] = nil
	if record == nil then
		return
	end
	pcall(function()
		local character = player.Character
		if character == nil then
			return
		end
		local shirt = character:FindFirstChildOfClass("Shirt")
		if shirt ~= nil then
			if record.CreatedShirt then
				shirt:Destroy()
			elseif record.Shirt ~= nil then
				shirt.ShirtTemplate = record.Shirt
			end
		end
		local pants = character:FindFirstChildOfClass("Pants")
		if pants ~= nil then
			if record.CreatedPants then
				pants:Destroy()
			elseif record.Pants ~= nil then
				pants.PantsTemplate = record.Pants
			end
		end
	end)
end

function UniformService:_watch(player: Player)
	player.CharacterAppearanceLoaded:Connect(function()
		-- A respawn gives a fresh character, so the old record no longer applies.
		self._saved[player] = nil
		self:_apply(player)
	end)
	if player.Character ~= nil then
		task.spawn(self._apply, self, player)
	end
end

---> lifecycle

function UniformService:KnitStart()
	self._shift = Knit.GetService("ShiftService")
	self._passSettings = Knit.GetService("PassSettingsService")
	self._passSettings.Changed:Connect(function(player: Player)
		if not self._shift:IsClockedIn(player) then
			return
		end
		if self:_keepsOwnOutfit(player) then
			self:_restore(player)
		else
			self:_apply(player)
		end
	end)
	self._shift.ClockedInChanged:Connect(function(player: Player, clockedIn: boolean)
		if clockedIn then
			self:_apply(player)
		else
			self:_restore(player)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			if wasPurchased and passId == STAR_EMPLOYEE_PASS_ID then
				if self._shift:IsClockedIn(player) then
					self:_apply(player)
				end
			end
		end
	)

	for _, player in Players:GetPlayers() do
		self:_watch(player)
	end
	Players.PlayerAdded:Connect(function(player)
		self:_watch(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._saved[player] = nil
	end)
end

return UniformService
