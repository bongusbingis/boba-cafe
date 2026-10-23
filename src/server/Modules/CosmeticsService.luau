---> services
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local InventoryServer = require(Shared.Inventory.InventoryServer)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local ProductIds = require(Shared.Configuration.ProductIds)

---> types
export type PlayerCosmetics = {
	Nickname: string,
	Nametag: string?,
}

---> globals
local cosmeticsCache: { [number]: PlayerCosmetics } = {}
local pendingNicknames: { [number]: { Nickname: string, CreatedAt: number } } = {}
local characterConnections: { [number]: RBXScriptConnection } = {}
local inventoryConnections: { [number]: RBXScriptConnection } = {}

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
		applyParticles(player.Character, getEquippedItem(proxy, "Particles", true))
	end,
}

function CosmeticsService:SetupPlayerCosmetics(player: Player, proxy)
	local existingCharacterConnection = characterConnections[player.UserId]
	if existingCharacterConnection then
		existingCharacterConnection:Disconnect()
		characterConnections[player.UserId] = nil
	end

	local existingInventoryConnection = inventoryConnections[player.UserId]
	if existingInventoryConnection then
		existingInventoryConnection:Disconnect()
		inventoryConnections[player.UserId] = nil
	end

	broadcast(player, proxy.Nickname or "", getEquippedItem(proxy, "Nametags"))
	applyParticles(player.Character, getEquippedItem(proxy, "Particles", true))

	characterConnections[player.UserId] = player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		COSMETIC_CHANGE_HANDLERS.Particles(player, proxy)
	end)

	local signal = InventoryServer:GetPlayerChangeSignal(player)
	if signal then
		inventoryConnections[player.UserId] = signal:Connect(function(changeData)
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

	local inventoryConn = inventoryConnections[player.UserId]
	if inventoryConn then
		inventoryConn:Disconnect()
		inventoryConnections[player.UserId] = nil
	end
end

function CosmeticsService:GetPendingNickname(player: Player): string?
	local pending = pendingNicknames[player.UserId]
	if pending == nil then
		return nil
	end
	if os.clock() - pending.CreatedAt > 3600 then
		pendingNicknames[player.UserId] = nil
		return nil
	end
	return pending.Nickname
end

function CosmeticsService:SetPendingNickname(player: Player, nickname: string)
	pendingNicknames[player.UserId] = {
		Nickname = nickname,
		CreatedAt = os.clock(),
	}
end

function CosmeticsService:ClearPendingNickname(player: Player)
	pendingNicknames[player.UserId] = nil
end

function CosmeticsService:RequestNicknameChange(
	player: Player,
	nickname: any
): { Success: boolean, Error: string?, Free: boolean? }
	if typeof(nickname) ~= "string" then
		return { Success = false, Error = "Invalid nickname input." }
	end

	local trimmed = string.match(nickname, "^%s*(.-)%s*$") or ""
	if #trimmed == 0 then
		return { Success = false, Error = "Nickname cannot be empty." }
	end

	if #trimmed > 15 then
		return { Success = false, Error = "Nickname must be 15 characters or less." }
	end

	local cached = cosmeticsCache[player.UserId]
	if cached ~= nil and cached.Nickname == trimmed then
		return { Success = false, Error = "That is already your current nickname." }
	end

	local okFilter, filterResult = pcall(function()
		return TextService:FilterStringAsync(trimmed, player.UserId)
	end)
	if not okFilter or filterResult == nil then
		return { Success = false, Error = "Unable to verify nickname at this time. Please try again." }
	end

	local okBroadcast, filtered = pcall(function()
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if not okBroadcast or typeof(filtered) ~= "string" or filtered ~= trimmed then
		return { Success = false, Error = "Nickname contains filtered content. Please choose another." }
	end

	local dataService = Knit.GetService("DataService")
	local dataOk, playerData = dataService:GetDataAsync(player):await()
	local currentNick = if playerData and playerData.Data
		then playerData.Data.Nickname
		elseif playerData then playerData.Nickname
		else nil
	local currentSkipped = if playerData and playerData.Data
		then playerData.Data.NicknameSkipped
		elseif playerData then playerData.NicknameSkipped
		else nil
	local isFirstFree = dataOk and playerData and (currentNick == "" and currentSkipped ~= true)

	if isFirstFree then
		playerData:SetValue({ "Nickname" }, filtered)
		self:NotifyNicknameChanged(player, filtered)
		player:SetAttribute("NicknamePending", nil)
		return { Success = true, Free = true }
	end

	self:SetPendingNickname(player, filtered)

	local productId = ProductIds.ChangeNickname
	if productId ~= nil then
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, productId)
		end)
	end

	return { Success = true, Free = false }
end

function CosmeticsService.Client:RequestNicknameChange(player: Player, nickname: any)
	return self.Server:RequestNicknameChange(player, nickname)
end

return CosmeticsService
