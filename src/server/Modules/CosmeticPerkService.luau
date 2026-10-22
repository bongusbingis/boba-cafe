--!strict
--[[
    Module: CosmeticPerkService
    Description: Publishes the cosmetic pass perks as player attributes
                 (REVIVAL-001 PASS-PORT lane A). Clients cannot resolve catalog-only
                 passes, so the server resolves ownership via PerkService.
                   VipTag      perk "VipTag"      -> player attribute `VipTag` (overhead star, chat colour)
                   RainbowPack perk "RainbowPack" -> player attribute `RainbowPack` (rainbow nametag,
                                                     and a rainbow Trail built here on the character)
                 Live game: Rainbow Pack granted an equippable Rainbow nametag and trail;
                 here they apply automatically (nametag only when no other nametag is equipped).
--]]

---> services

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies

local Knit = require(Packages.Knit)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local PassCatalog = require(Shared.Configuration.PassCatalog)
local PassCosmetics = require(Shared.Configuration.PassCosmetics)

---> constants

local PERK_ATTRIBUTES = {
	VipTag = PassCosmetics.VIP_ATTRIBUTE,
	RainbowPack = PassCosmetics.RAINBOW_ATTRIBUTE,
}
local TRAIL_TAG = "RainbowPackTrail"

---> service

local CosmeticPerkService = Knit.CreateService({
	Name = "CosmeticPerkService",
	Client = {},

	_characterConns = {} :: { [Player]: RBXScriptConnection },
})

---> private

function CosmeticPerkService:_removeTrail(character: Model)
	for _, item in character:GetDescendants() do
		if item:GetAttribute(TRAIL_TAG) then
			item:Destroy()
		end
	end
end

function CosmeticPerkService:_applyTrail(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	self:_removeTrail(character)
	if player:GetAttribute(PassCosmetics.RAINBOW_ATTRIBUTE) ~= true then
		return
	end

	local parent = character:FindFirstChild("UpperTorso") or character:WaitForChild("HumanoidRootPart", 5)
	if parent == nil or player.Character ~= character then
		return
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.CFrame = CFrame.new(0, 0.2, 0)
	attachment0:SetAttribute(TRAIL_TAG, true)
	attachment0.Parent = parent

	local attachment1 = Instance.new("Attachment")
	attachment1.CFrame = CFrame.new(0, -0.7, 0)
	attachment1:SetAttribute(TRAIL_TAG, true)
	attachment1.Parent = parent

	local trail = Instance.new("Trail")
	trail.Color = PassCosmetics.RAINBOW_TRAIL_COLOR
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail:SetAttribute(TRAIL_TAG, true)
	trail.Parent = character
end

-- Resolves each cosmetic perk once (yields on a cold pass cache).
function CosmeticPerkService:_refresh(player: Player)
	for perk, attribute in PERK_ATTRIBUTES do
		local owns = self._perks:HasPerk(player, perk)
		if player.Parent ~= nil then
			player:SetAttribute(attribute, owns)
		end
	end
	if player.Parent ~= nil then
		self:_applyTrail(player)
	end
end

---> public

function CosmeticPerkService:PlayerAdded(player: Player)
	self._characterConns[player] = player.CharacterAdded:Connect(function()
		self:_applyTrail(player)
	end)
	task.spawn(function()
		self:_refresh(player)
	end)
end

function CosmeticPerkService:PlayerRemoving(player: Player)
	local conn = self._characterConns[player]
	if conn ~= nil then
		conn:Disconnect()
		self._characterConns[player] = nil
	end
end

---> lifecycle

function CosmeticPerkService:KnitStart()
	self._perks = Knit.GetService("PerkService")

	-- In-session purchase: the pass cache would still say "not owned" until rejoin.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			if not wasPurchased then
				return
			end
			local entry = PassCatalog[passId]
			if entry == nil then
				return
			end
			local relevant = false
			for perk in PERK_ATTRIBUTES do
				if table.find(entry.Perks, perk) ~= nil then
					relevant = true
				end
			end
			if not relevant then
				return
			end
			pcall(function()
				(GamepassUtil :: any):GrantPassToCache(player, passId)
			end)
			self:_refresh(player)
		end
	)
end

return CosmeticPerkService
