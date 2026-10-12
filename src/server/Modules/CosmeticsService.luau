---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local InventoryServer = require(Shared.Inventory.InventoryServer)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

---> constants

-- "Nametag Customizer" pass. Recolouring is gated on owning it.
local NAMETAG_CUSTOMIZER_PASS_ID = 29083693

---> types
export type PlayerCosmetics = {
	Nickname: string,
	Nametag: string?,
}

---> globals
local cosmeticsCache: { [number]: PlayerCosmetics } = {}
local characterConnections: { [number]: RBXScriptConnection } = {}

---> service declaration
local CosmeticsService = Knit.CreateService({
	Name = "CosmeticsService",
	Client = {
		CosmeticsChanged = Knit.CreateSignal(),
	},
})

---> private helpers

local function particles(particleName: string, numEquipped: number): ParticleEmitter
	local this = Instance.new("ParticleEmitter")

	this.Acceleration = Vector3.new(0, -0.10000000149011612, 0)
	this.Lifetime = NumberRange.new(3, 6)
	this.LightInfluence = 1
	this.LockedToPart = true
	this.Rate = 3 / numEquipped
	this.RotSpeed = NumberRange.new(-90, 90)
	this.Rotation = NumberRange.new(-180, 180)
	this.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.05, 0.6, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	this.Speed = NumberRange.new(0.5, 0.75)
	this.SpreadAngle = Vector2.new(180, 180)
	this.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0.5),
	})

	print(particleName)
	local itemDef = InventoryItemDefinitions.Particles[particleName]
	this.Texture = itemDef.Image

	return this
end

local function getEquippedItem(proxy, itemType: string, all: boolean?)
	local items = proxy.Inventory and proxy.Inventory.Items and proxy.Inventory.Items[itemType]
	if not items then
		return nil
	end

	if all then
		local equippedItems = {}
		for _, item in items do
			if item.Equipped then
				table.insert(equippedItems, item.Name)
			end
		end
		return equippedItems
	else
		for _, item in items do
			if item.Equipped then
				return item.Name
			end
		end
	end
	return nil
end

--- Stored channels -> Color3, or nil when the player has no custom tint.
local function toColor3(stored): Color3?
	if typeof(stored) ~= "table" then
		return nil
	end
	return Color3.fromRGB(stored.R or 255, stored.G or 255, stored.B or 255)
end

local function broadcast(player: Player, nickname: string, nametag: string?, nametagColor: Color3?)
	-- Preserve the cached colour when a caller does not supply one, so unrelated
	-- broadcasts (nickname changes, respawns) do not clear a player's custom tint.
	local cached = cosmeticsCache[player.UserId]
	local color = nametagColor or (cached and cached.NametagColor)

	cosmeticsCache[player.UserId] = { Nickname = nickname, Nametag = nametag, NametagColor = color }
	CosmeticsService.Client.CosmeticsChanged:FireAll(player.UserId, nickname, nametag, color)
end

local function applyParticles(character: Model?, particlesToApply: { string }?)
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	for _, child in root:GetChildren() do
		if child:GetAttribute("ManagedParticle") then
			child:Destroy()
		end
	end

	if not particlesToApply or #particlesToApply == 0 then
		return
	end

	for _, particleName in particlesToApply do
		local particleEmitter = particles(particleName, #particlesToApply)
		particleEmitter:SetAttribute("ManagedParticle", true)
		particleEmitter.Parent = root
	end
end

local COSMETIC_CHANGE_HANDLERS: { [string]: (player: Player, proxy: any) -> () } = {
	Nametags = function(player, proxy)
		local cached = cosmeticsCache[player.UserId]
		broadcast(player, cached and cached.Nickname or "", getEquippedItem(proxy, "Nametags"))
	end,

	Particles = function(player, proxy)
		print("n", #getEquippedItem(proxy, "Particles", true))
		applyParticles(player.Character, getEquippedItem(proxy, "Particles", true))
	end,
}

function CosmeticsService:SetupPlayerCosmetics(player: Player, proxy)
	broadcast(player, proxy.Nickname or "", getEquippedItem(proxy, "Nametags"), toColor3(proxy.NametagColor))
	applyParticles(player.Character, getEquippedItem(proxy, "Particles", true))

	characterConnections[player.UserId] = player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		COSMETIC_CHANGE_HANDLERS.Particles(player, proxy)
	end)

	local signal = InventoryServer:GetPlayerChangeSignal(player)
	if signal then
		signal:Connect(function(changeData)
			if changeData.action ~= "equipped" then
				return
			end
			local handler = COSMETIC_CHANGE_HANDLERS[changeData.itemsType]
			if handler then
				handler(player, proxy)
			end
		end)
	end
end

function CosmeticsService:NotifyNicknameChanged(player: Player, nickname: string)
	local cached = cosmeticsCache[player.UserId]
	broadcast(player, nickname, cached and cached.Nametag)
end

--[=[
	Sets the player's custom nametag tint. Requires the Nametag Customizer pass and a
	non-animated nametag equipped — animated tags drive their own colours, so a static
	tint would fight the animation (V4 applied the same rule).

	Pass nil to clear. Returns (success, message).
]=]
function CosmeticsService.Client:SetNametagColor(player: Player, color: Color3?): (boolean, string)
	if color ~= nil and typeof(color) ~= "Color3" then
		return false, "Invalid colour."
	end

	if not GamepassUtil:PlayerOwnsPassAsync(player, NAMETAG_CUSTOMIZER_PASS_ID) then
		return false, "You don't own the Nametag Customizer pass."
	end

	local ok, proxy = Knit.GetService("DataService"):GetDataAsync(player):await()
	if not ok or not proxy then
		return false, "Your data could not be loaded."
	end

	local equipped = getEquippedItem(proxy, "Nametags")
	if not equipped then
		return false, "Equip a nametag first."
	end

	local definition = InventoryItemDefinitions.Nametags[equipped]
	if definition and definition.Animation then
		return false, "Animated nametags can't be recoloured."
	end

	if color == nil then
		proxy:SetValue({ "NametagColor" }, false)
	else
		proxy:SetValue({ "NametagColor" }, {
			R = math.round(color.R * 255),
			G = math.round(color.G * 255),
			B = math.round(color.B * 255),
		})
	end

	broadcast(player, proxy.Nickname or "", equipped, color)

	return true, if color then "Nametag colour updated!" else "Nametag colour reset."
end

function CosmeticsService.Client:GetAllPlayerCosmeticsAsync(): { [number]: PlayerCosmetics }
	return cosmeticsCache
end

function CosmeticsService:PlayerRemoving(player: Player)
	cosmeticsCache[player.UserId] = nil

	local conn = characterConnections[player.UserId]
	if conn then
		conn:Disconnect()
		characterConnections[player.UserId] = nil
	end
end

return CosmeticsService
