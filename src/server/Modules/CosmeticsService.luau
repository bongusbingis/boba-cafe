---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local InventoryServer = require(Shared.Inventory.InventoryServer)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)

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

local function broadcast(player: Player, nickname: string, nametag: string?)
	cosmeticsCache[player.UserId] = { Nickname = nickname, Nametag = nametag }
	CosmeticsService.Client.CosmeticsChanged:FireAll(player.UserId, nickname, nametag)
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
	broadcast(player, proxy.Nickname or "", getEquippedItem(proxy, "Nametags"))
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
