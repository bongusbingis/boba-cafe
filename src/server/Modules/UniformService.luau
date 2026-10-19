--!strict
--[[
    Module: UniformService
    Description: Clocked-in baristas wear the Default uniform (REVIVAL-001 NPC-LOOK).
                 On clock-in the character's Shirt/Pants templates are recorded and set
                 to SharedStorage.KitchenStorage.Assets.S_DefaultUniform / P_DefaultUniform;
                 on clock-out they are restored. A missing uniform asset warns once and
                 skips. Visuals are UNVERIFIED until M1.6.
--]]

---> services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies

local Knit = require(Packages.Knit)
local WorldPath = require(Shared.Utility.WorldPath)

---> types

type Saved = {
	Shirt: string?, -- original template; nil when the instance did not exist
	Pants: string?,
	CreatedShirt: boolean,
	CreatedPants: boolean,
}

---> constants

local ASSET_TIMEOUT_SECONDS = 5

---> service

local UniformService = Knit.CreateService({
	Name = "UniformService",
	Client = {},

	_saved = {} :: { [Player]: Saved },
	_warned = false,
})

---> private

function UniformService:_warnOnce(message: string)
	if not self._warned then
		self._warned = true
		warn(`[UniformService] {message}`)
	end
end

-- The template string of a Shirt/Pants asset, or nil (warns once).
function UniformService:_template(name: string, className: "Shirt" | "Pants"): string?
	local asset = WorldPath.waitFor(
		ReplicatedStorage:FindFirstChild("SharedStorage"),
		{ "KitchenStorage", "Assets", name },
		ASSET_TIMEOUT_SECONDS
	)
	if asset == nil or not asset:IsA(className) then
		self:_warnOnce(`SharedStorage.KitchenStorage.Assets.{name} is missing; no uniform for that piece.`)
		return nil
	end
	return if className == "Shirt" then (asset :: Shirt).ShirtTemplate else (asset :: Pants).PantsTemplate
end

function UniformService:_apply(player: Player)
	pcall(function()
		local character = player.Character
		if character == nil or not self._shift:IsClockedIn(player) then
			return
		end
		local shirtTemplate = self:_template("S_DefaultUniform", "Shirt")
		local pantsTemplate = self:_template("P_DefaultUniform", "Pants")
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
	self._shift.ClockedInChanged:Connect(function(player: Player, clockedIn: boolean)
		if clockedIn then
			self:_apply(player)
		else
			self:_restore(player)
		end
	end)
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
