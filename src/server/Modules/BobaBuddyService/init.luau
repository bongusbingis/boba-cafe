--!strict
--[[
	BobaBuddyService
	Server service managing the lifecycle, behaviors, and stacking of
	consumable Boba Buddy companions (Cleaner and Stocker).
--]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local BobaBuddyConfig = require(Shared.Configuration.BobaBuddyConfig)

local CleanerBehavior = require(script.CleanerBehavior)
local StockerBehavior = require(script.StockerBehavior)
local FollowBehavior = require(script.FollowBehavior)
local Nametag = require(script.Nametag)
local AnimationController = require(script.AnimationController)

local NPC_COLLISION_GROUP = "NPC"

type ActiveBuddy = {
	Model: Model,
	Chore: "Cleaner" | "Stocker",
	Owner: Player,
	ExpiresAt: number,
	StopFollow: () -> (),
	StopChore: () -> (),
	StopAnim: () -> (),
	IsBusy: boolean,
}

local BobaBuddyService = Knit.CreateService({
	Name = "BobaBuddyService",
	Client = {
		BuddySpawned = Knit.CreateSignal(),
		BuddyDespawned = Knit.CreateSignal(),
	},
	_activeBuddies = {} :: { [Player]: { [string]: ActiveBuddy } },
	_buddiesFolder = nil :: Folder?,
})

local function ensureCollisionGroups()
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered(NPC_COLLISION_GROUP) then
			PhysicsService:RegisterCollisionGroup(NPC_COLLISION_GROUP)
		end
		if not PhysicsService:IsCollisionGroupRegistered("Players") then
			PhysicsService:RegisterCollisionGroup("Players")
		end
		PhysicsService:CollisionGroupSetCollidable(NPC_COLLISION_GROUP, "Players", false)
		PhysicsService:CollisionGroupSetCollidable(NPC_COLLISION_GROUP, NPC_COLLISION_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(NPC_COLLISION_GROUP, "Default", true)
	end)
end

local function applyCollisionGroup(model: Model)
	ensureCollisionGroups()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			pcall(function()
				descendant.CollisionGroup = NPC_COLLISION_GROUP
			end)
		end
	end
	model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			pcall(function()
				descendant.CollisionGroup = NPC_COLLISION_GROUP
			end)
		end
	end)
end

local function applyRoleColors(model: Model, chore: "Cleaner" | "Stocker")
	local colorConfig = BobaBuddyConfig.COLORS and BobaBuddyConfig.COLORS[chore]
	if not colorConfig then
		return
	end

	local skinColor = colorConfig.Skin
	local liquidColor = colorConfig.Liquid

	-- 1. BodyColors
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = skinColor
		bodyColors.LeftArmColor3 = skinColor
		bodyColors.RightArmColor3 = skinColor
		bodyColors.LeftLegColor3 = skinColor
		bodyColors.RightLegColor3 = skinColor
		bodyColors.TorsoColor3 = skinColor
	end

	-- 2. Character limb BaseParts
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and child.Name ~= "BobaCostume" then
			child.Color = skinColor
		end
	end

	-- 3. BobaCostume.Liquid
	local costume = model:FindFirstChild("BobaCostume")
	if costume then
		local liquid = costume:FindFirstChild("Liquid")
		if liquid and liquid:IsA("BasePart") then
			liquid.Color = liquidColor
		end
	end
end

function BobaBuddyService:KnitInit()
	local folder = workspace:FindFirstChild("BobaBuddies") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BobaBuddies"
		folder.Parent = workspace
	end
	self._buddiesFolder = folder
	ensureCollisionGroups()
end

function BobaBuddyService:KnitStart()
	local shiftService = Knit.GetService("ShiftService")

	-- Listen for clock-out: despawn all active buddies for that player
	local function onPlayerClockOut(player: Player)
		local buddies = self._activeBuddies[player]
		if buddies then
			for chore, _ in pairs(buddies) do
				self:DespawnBuddy(player, chore)
			end
		end
	end

	if shiftService and (shiftService :: any).ClockedOut then
		(shiftService :: any).ClockedOut:Connect(onPlayerClockOut)
	end

	-- Also watch ClockedIn attribute changes
	for _, player in Players:GetPlayers() do
		player:GetAttributeChangedSignal("ClockedIn"):Connect(function()
			if player:GetAttribute("ClockedIn") == false then
				onPlayerClockOut(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		player:GetAttributeChangedSignal("ClockedIn"):Connect(function()
			if player:GetAttribute("ClockedIn") == false then
				onPlayerClockOut(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local buddies = self._activeBuddies[player]
		if buddies then
			for chore, _ in pairs(buddies) do
				self:DespawnBuddy(player, chore, true)
			end
			self._activeBuddies[player] = nil
		end
	end)

	-- Expiration loop
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for player, buddies in pairs(self._activeBuddies) do
				for chore, buddy in pairs(buddies) do
					if now >= buddy.ExpiresAt then
						self:DespawnBuddy(player, chore)
					end
				end
			end
		end
	end)
end

function BobaBuddyService:SpawnBuddyForPlayer(player: Player, chore: "Cleaner" | "Stocker"): (boolean, string?)
	local shiftService = Knit.GetService("ShiftService")
	local isClockedIn = player:GetAttribute("ClockedIn") == true
	if shiftService and shiftService.IsClockedIn then
		isClockedIn = shiftService:IsClockedIn(player)
	end

	if not isClockedIn then
		return false, "NotClockedIn"
	end

	if not self._activeBuddies[player] then
		self._activeBuddies[player] = {}
	end

	-- Stacking logic: if player already owns this buddy chore, extend timer
	local existing = self._activeBuddies[player][chore]
	if existing and BobaBuddyConfig.STACK_MODE == "Extend" then
		existing.ExpiresAt += BobaBuddyConfig.LIFESPAN_SECONDS
		return true, "Extended"
	end

	local sharedStorage = ReplicatedStorage:FindFirstChild("SharedStorage")
	local npcs = sharedStorage and sharedStorage:FindFirstChild("NPCs")
	local template = npcs and npcs:FindFirstChild("BobaBuddy")
	if not template or not template:IsA("Model") then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local assetsNpcs = assets and assets:FindFirstChild("NPCs")
		template = assetsNpcs and assetsNpcs:FindFirstChild("BobaBuddy")
	end

	if not template or not template:IsA("Model") then
		return false, "ModelFailed"
	end

	local model = template:Clone()

	model.Name = `{player.Name}_BobaBuddy_{chore}`
	model:SetAttribute("IsBobaBuddy", true)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Chore", chore)
	model:SetAttribute("BuiltBy", "BOBA-BUDDY-CONSUMABLE-001")

	-- Apply role skin & liquid colors
	applyRoleColors(model, chore)

	-- Put in NPC collision group so buddy never collides with players or customer NPCs
	applyCollisionGroup(model)

	local ownerChar = player.Character
	local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")
	if ownerRoot then
		model:PivotTo(ownerRoot.CFrame * CFrame.new(Vector3.new(4, 0, 4)))
	end
	model.Parent = self._buddiesFolder

	local expiresAt = os.clock() + BobaBuddyConfig.LIFESPAN_SECONDS
	local isBusy = false

	local stopFollow = FollowBehavior.Start(model, player, function()
		return isBusy
	end)

	local stopChore: () -> ()
	if chore == "Cleaner" then
		stopChore = CleanerBehavior.Start(model, player, function(busy: boolean)
			isBusy = busy
		end)
	else
		stopChore = StockerBehavior.Start(model, player, function(busy: boolean)
			isBusy = busy
		end)
	end

	local rootPart = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		pcall(function()
			rootPart:SetNetworkOwner(nil)
		end)
	end

	local animController = AnimationController.Attach(model)

	-- FredokaOne nametag: "{username}'s Boba Buddy" with chore role underneath and nothing else
	Nametag.Attach(model, player, chore)

	local activeBuddy: ActiveBuddy = {
		Model = model,
		Chore = chore,
		Owner = player,
		ExpiresAt = expiresAt,
		StopFollow = stopFollow,
		StopChore = stopChore,
		StopAnim = animController.Stop,
		IsBusy = false,
	}

	self._activeBuddies[player][chore] = activeBuddy
	self.Client.BuddySpawned:Fire(player, chore, BobaBuddyConfig.LIFESPAN_SECONDS)

	return true, "Spawned"
end

function BobaBuddyService:DespawnBuddy(player: Player, chore: string, immediate: boolean?)
	local buddies = self._activeBuddies[player]
	if not buddies or not buddies[chore] then
		return
	end

	local buddy = buddies[chore]
	buddies[chore] = nil

	if buddy.StopAnim then
		buddy.StopAnim()
	end
	buddy.StopFollow()
	buddy.StopChore()

	if buddy.Model and buddy.Model.Parent then
		if immediate then
			buddy.Model:Destroy()
		else
			task.spawn(function()
				-- Smooth fade out
				for _ = 1, 10 do
					for _, desc in buddy.Model:GetDescendants() do
						if desc:IsA("BasePart") then
							desc.Transparency = math.min(1, desc.Transparency + 0.1)
						end
					end
					task.wait(0.05)
				end
				buddy.Model:Destroy()
			end)
		end
	end

	self.Client.BuddyDespawned:Fire(player, chore)
end

function BobaBuddyService:GetActiveBuddy(player: Player, chore: string): any?
	local buddies = self._activeBuddies[player]
	return buddies and buddies[chore]
end

return BobaBuddyService
