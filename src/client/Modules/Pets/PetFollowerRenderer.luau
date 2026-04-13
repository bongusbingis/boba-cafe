--!nonstrict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local Config = require(script.Parent.PetFollowerConfig)

type EquippedPetSnapshot = {
	ItemId: string,
	Name: string,
	DisplayName: string,
	Tier: string?,
}

type FollowerState = {
	UserId: number,
	Snapshot: EquippedPetSnapshot,
	Container: Instance?,
	RootPart: BasePart?,
	Billboard: BillboardGui?,
	NameLabel: TextLabel?,
	MetaLabel: TextLabel?,
	CurrentCFrame: CFrame?,
	TargetCFrame: CFrame?,
	NextTargetUpdateAt: number,
	LastVisibleAt: number,
	SideSign: number,
	BobPhase: number,
	Visible: boolean,
	CurrentQuality: string?,
}

local PetFollowerRenderer = {}
PetFollowerRenderer.__index = PetFollowerRenderer

local PetDefinitions = InventoryItemDefinitions.Pets
local TierDefinitions = InventoryItemDefinitions.Tiers

local function getTierColor(tierName: string?): Color3
	if tierName and TierDefinitions[tierName] and TierDefinitions[tierName].Color then
		return TierDefinitions[tierName].Color
	end
	return Color3.new(1, 1, 1)
end

local function getPetTypeName(petDefinitionName: string): string
	local stripped = petDefinitionName:gsub("%s+[Pp]et$", "")
	if stripped == "" then
		return petDefinitionName
	end
	return stripped
end

local function resolveOwnerRoot(userId: number): (Player?, BasePart?)
	local owner = Players:GetPlayerByUserId(userId)
	if not owner then
		return nil, nil
	end

	local character = owner.Character
	if not character then
		return owner, nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return owner, root
	end

	return owner, nil
end

local function resolveRootPart(container: Instance): BasePart?
	if container:IsA("BasePart") then
		return container
	end

	if container:IsA("Model") then
		local model = container :: Model
		if model.PrimaryPart then
			return model.PrimaryPart
		end

		local humanoidRootPart = model:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
			model.PrimaryPart = humanoidRootPart
			return humanoidRootPart
		end

		local firstBasePart = model:FindFirstChildWhichIsA("BasePart", true)
		if firstBasePart then
			model.PrimaryPart = firstBasePart
			return firstBasePart
		end
	end

	return nil
end

local function applyVisualPartSettings(container: Instance)
	for _, descendant in container:GetDescendants() do
		if
			descendant:IsA("Script")
			or descendant:IsA("LocalScript")
			or descendant:IsA("Humanoid")
			or descendant:IsA("Animator")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.CastShadow = false
		end
	end

	if container:IsA("BasePart") then
		local part = container :: BasePart
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = false
	end
end

local function setContainerCFrame(container: Instance, cframe: CFrame)
	if container:IsA("Model") then
		(container :: Model):PivotTo(cframe)
	elseif container:IsA("BasePart") then
		(container :: BasePart).CFrame = cframe
	end
end

local function getContainerSize(container: Instance): Vector3
	if container:IsA("Model") then
		local _, size = (container :: Model):GetBoundingBox()
		return size
	elseif container:IsA("BasePart") then
		return (container :: BasePart).Size
	end

	return Vector3.new(2, 2, 2)
end

local function resolveBillboardTextLabels(billboard: BillboardGui): (TextLabel?, TextLabel?)
	local function asTextLabel(instance: Instance?): TextLabel?
		if instance and instance:IsA("TextLabel") then
			return instance
		end
		return nil
	end

	local nameLabel = asTextLabel(billboard:FindFirstChild("PetName", true))
	local metaLabel = asTextLabel(billboard:FindFirstChild("Tier", true))
		or asTextLabel(billboard:FindFirstChild("PetMeta", true))

	if nameLabel and metaLabel and nameLabel ~= metaLabel then
		return nameLabel, metaLabel
	end

	local first: TextLabel? = nil
	local second: TextLabel? = nil
	for _, descendant in billboard:GetDescendants() do
		if descendant:IsA("TextLabel") then
			if first == nil then
				first = descendant
			elseif second == nil and descendant ~= first then
				second = descendant
				break
			end
		end
	end

	if not nameLabel then
		nameLabel = first
	end
	if not metaLabel then
		metaLabel = if second and second ~= nameLabel then second else nil
	end

	return nameLabel, metaLabel
end

function PetFollowerRenderer.new(localPlayer: Player)
	local existingFolder = Workspace:FindFirstChild("ClientPetFollowers")
	local renderFolder = if existingFolder and existingFolder:IsA("Folder")
		then existingFolder
		else Instance.new("Folder")
	renderFolder.Name = "ClientPetFollowers"
	renderFolder.Parent = Workspace

	local self = setmetatable({
		_localPlayer = localPlayer,
		_playerGui = localPlayer:WaitForChild("PlayerGui"),
		_renderFolder = renderFolder,
		_followers = {} :: { [number]: FollowerState },
		_allowedRemoteUserIds = {} :: { [number]: boolean },
		_nextBudgetRefreshAt = 0,
		_heartbeatConnection = nil,
	}, PetFollowerRenderer)

	self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)

	return self
end

function PetFollowerRenderer:_destroyVisual(follower: FollowerState)
	if follower.Billboard then
		follower.Billboard:Destroy()
		follower.Billboard = nil
		follower.NameLabel = nil
		follower.MetaLabel = nil
	end

	if follower.Container then
		follower.Container:Destroy()
		follower.Container = nil
		follower.RootPart = nil
	end

	follower.Visible = false
end

function PetFollowerRenderer:_setVisible(follower: FollowerState, visible: boolean)
	if follower.Visible == visible then
		return
	end

	follower.Visible = visible

	if visible then
		follower.LastVisibleAt = os.clock()
		if follower.Container then
			follower.Container.Parent = self._renderFolder
		end
		if follower.Billboard then
			follower.Billboard.Parent = self._playerGui
		end
	else
		if follower.Container then
			follower.Container.Parent = nil
		end
		if follower.Billboard then
			follower.Billboard.Parent = nil
		end
	end
end

function PetFollowerRenderer:_createBillboard(follower: FollowerState)
	local Overhead = Instance.new("BillboardGui")
	Overhead.Name = "Overhead"
	Overhead.Size = UDim2.fromScale(3.5, 2)
	Overhead.AlwaysOnTop = false
	Overhead.LightInfluence = 0
	Overhead.MaxDistance = Config.MaxRenderDistance

	local Tier = Instance.new("TextLabel")
	Tier.Name = "Tier"
	Tier.BackgroundTransparency = 1
	Tier.FontFace =
		Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	Tier.Position = UDim2.fromScale(0, 0.725)
	Tier.Size = UDim2.fromScale(1, 0.15)
	Tier.Text = "Username"
	Tier.TextColor3 = Color3.new(1, 1, 1)
	Tier.TextScaled = true
	Tier.Parent = Overhead

	local PetName = Instance.new("TextLabel")
	PetName.Name = "PetName"
	PetName.AnchorPoint = Vector2.new(0.5, 0)
	PetName.BackgroundTransparency = 1
	PetName.FontFace = Font.new("rbxasset://fonts/families/DenkOne.json")
	PetName.Position = UDim2.fromScale(0.5, 0.45)
	PetName.Size = UDim2.fromScale(3, 0.3)
	PetName.Text = "Nickname"
	PetName.TextColor3 = Color3.new(1, 1, 1)
	PetName.TextScaled = true
	PetName.Parent = Overhead

	follower.Billboard = Overhead
	follower.NameLabel, follower.MetaLabel = resolveBillboardTextLabels(Overhead)

	self:_refreshBillboard(follower)
end

function PetFollowerRenderer:_refreshBillboard(follower: FollowerState)
	if not follower.Billboard or not follower.RootPart then
		return
	end

	if not follower.NameLabel or not follower.MetaLabel then
		follower.NameLabel, follower.MetaLabel = resolveBillboardTextLabels(follower.Billboard)
	end

	if not follower.NameLabel then
		return
	end

	local size = if follower.Container then getContainerSize(follower.Container) else Vector3.new(2, 2, 2)
	follower.Billboard.Adornee = follower.RootPart
	follower.Billboard.StudsOffsetWorldSpace = Vector3.new(0, math.max(2.05, size.Y * 0.45 + 1.05), 0)

	follower.NameLabel.Text = follower.Snapshot.DisplayName
	follower.NameLabel.TextColor3 = Color3.new(1, 1, 1)

	if follower.MetaLabel then
		local tierText = follower.Snapshot.Tier or "Unknown"
		local typeText = getPetTypeName(follower.Snapshot.Name)
		follower.MetaLabel.Text = string.format("%s %s", tierText, typeText)
		follower.MetaLabel.TextColor3 = getTierColor(follower.Snapshot.Tier)
	end
end

function PetFollowerRenderer:_ensureVisual(follower: FollowerState): boolean
	if follower.Container and follower.RootPart and follower.Billboard then
		self:_refreshBillboard(follower)
		return true
	end

	local definition = PetDefinitions[follower.Snapshot.Name]
	if not definition or typeof(definition.PetModel) ~= "Instance" then
		warn("[PetFollowerRenderer]: Missing PetModel for", follower.Snapshot.Name)
		return false
	end

	local template: Instance = definition.PetModel
	local clone = template:Clone()
	local container: Instance = clone

	if not clone:IsA("Model") and not clone:IsA("BasePart") then
		local model = Instance.new("Model")
		clone.Parent = model
		container = model
	end

	applyVisualPartSettings(container)

	local rootPart = resolveRootPart(container)
	if not rootPart then
		container:Destroy()
		warn("[PetFollowerRenderer]: Failed to resolve root part for", follower.Snapshot.Name)
		return false
	end

	follower.Container = container
	follower.RootPart = rootPart
	self:_createBillboard(follower)
	self:_setVisible(follower, true)

	return true
end

function PetFollowerRenderer:_computeTarget(
	ownerRoot: BasePart,
	now: number,
	follower: FollowerState,
	settings: any
): CFrame
	local look = ownerRoot.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 1e-4 then
		flatLook = Vector3.new(0, 0, -1)
	else
		flatLook = flatLook.Unit
	end

	local right = ownerRoot.CFrame.RightVector
	local flatRight = Vector3.new(right.X, 0, right.Z)
	if flatRight.Magnitude < 1e-4 then
		flatRight = Vector3.new(1, 0, 0)
	else
		flatRight = flatRight.Unit
	end

	local velocity = ownerRoot.AssemblyLinearVelocity
	local planarSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local trailBoost = math.clamp(planarSpeed * settings.VelocityTrailScale, 0, settings.MaxTrailBoost)

	local bob = math.sin(now * settings.BobSpeed + follower.BobPhase) * settings.BobAmplitude
	local sway = math.cos(now * settings.BobSpeed * 0.5 + follower.BobPhase) * settings.SideSway

	local position = ownerRoot.Position
		- flatLook * (settings.TrailDistance + trailBoost)
		+ flatRight * (settings.SideOffset * follower.SideSign + sway)
		+ Vector3.new(0, settings.Height + bob, 0)

	local lookAt = ownerRoot.Position + Vector3.new(0, settings.LookHeight, 0)
	local base = CFrame.lookAt(position, lookAt)
	local tilt = math.sin(now * settings.BobSpeed + follower.BobPhase) * settings.TiltRadians

	return base * CFrame.Angles(tilt, 0, 0)
end

function PetFollowerRenderer:_resolveQuality(userId: number, distanceSquared: number): string?
	if userId == self._localPlayer.UserId then
		return "local"
	end

	if not self._allowedRemoteUserIds[userId] then
		return nil
	end

	local highSq = Config.HighDetailDistance * Config.HighDetailDistance
	if distanceSquared <= highSq then
		return "high"
	end

	local mediumSq = Config.MediumDetailDistance * Config.MediumDetailDistance
	if distanceSquared <= mediumSq then
		return "medium"
	end

	local maxSq = Config.MaxRenderDistance * Config.MaxRenderDistance
	if distanceSquared <= maxSq then
		return "low"
	end

	return nil
end

function PetFollowerRenderer:_refreshRemoteBudget(cameraPosition: Vector3)
	local maxSq = Config.MaxRenderDistance * Config.MaxRenderDistance
	local ranked = {}

	for userId, _ in self._followers do
		if userId == self._localPlayer.UserId then
			continue
		end

		local _, ownerRoot = resolveOwnerRoot(userId)
		if not ownerRoot then
			continue
		end

		local offset = ownerRoot.Position - cameraPosition
		local distanceSquared = offset:Dot(offset)
		if distanceSquared <= maxSq then
			table.insert(ranked, {
				UserId = userId,
				DistanceSquared = distanceSquared,
			})
		end
	end

	table.sort(ranked, function(a, b)
		return a.DistanceSquared < b.DistanceSquared
	end)

	self._allowedRemoteUserIds = {}
	local keep = math.min(#ranked, Config.MaxRemoteVisible)
	for index = 1, keep do
		self._allowedRemoteUserIds[ranked[index].UserId] = true
	end
end

function PetFollowerRenderer:_step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local now = os.clock()
	local cameraPosition = camera.CFrame.Position

	if now >= self._nextBudgetRefreshAt then
		self:_refreshRemoteBudget(cameraPosition)
		self._nextBudgetRefreshAt = now + Config.RemoteBudgetRefreshInterval
	end

	for userId, follower in self._followers do
		local _, ownerRoot = resolveOwnerRoot(userId)
		if not ownerRoot then
			self:_setVisible(follower, false)
			continue
		end

		local offset = ownerRoot.Position - cameraPosition
		local distanceSquared = offset:Dot(offset)
		local quality = self:_resolveQuality(userId, distanceSquared)

		if not quality then
			self:_setVisible(follower, false)
			if
				follower.Container
				and userId ~= self._localPlayer.UserId
				and now - follower.LastVisibleAt >= Config.DespawnAfterSeconds
			then
				self:_destroyVisual(follower)
			end
			continue
		end

		follower.CurrentQuality = quality
		if not self:_ensureVisual(follower) then
			continue
		end

		self:_setVisible(follower, true)
		local settings = Config.QualitySettings[quality]
		if not settings then
			continue
		end

		if settings.TargetInterval <= 0 or now >= follower.NextTargetUpdateAt then
			follower.TargetCFrame = self:_computeTarget(ownerRoot, now, follower, settings)
			follower.NextTargetUpdateAt = now + settings.TargetInterval
		end

		if follower.TargetCFrame then
			if not follower.CurrentCFrame then
				follower.CurrentCFrame = follower.TargetCFrame
			end

			local alpha = 1 - math.exp(-settings.Smoothing * dt)
			follower.CurrentCFrame = follower.CurrentCFrame:Lerp(follower.TargetCFrame, alpha)

			if follower.Container then
				setContainerCFrame(follower.Container, follower.CurrentCFrame)
			end
		end
	end
end

function PetFollowerRenderer:SyncEquippedPets(userId: number, equippedPets: { EquippedPetSnapshot })
	local primaryPet = equippedPets and equippedPets[1] or nil
	if not primaryPet then
		self:RemoveFollower(userId)
		return
	end

	local follower = self._followers[userId]
	if follower and follower.Snapshot.ItemId == primaryPet.ItemId then
		follower.Snapshot = table.clone(primaryPet)
		self:_refreshBillboard(follower)
		return
	end

	if follower then
		self:_destroyVisual(follower)
	end

	self._followers[userId] = {
		UserId = userId,
		Snapshot = table.clone(primaryPet),
		Container = nil,
		RootPart = nil,
		Billboard = nil,
		NameLabel = nil,
		MetaLabel = nil,
		CurrentCFrame = nil,
		TargetCFrame = nil,
		NextTargetUpdateAt = 0,
		LastVisibleAt = os.clock(),
		SideSign = if userId % 2 == 0 then 1 else -1,
		BobPhase = (userId % 37) * 0.77,
		Visible = false,
		CurrentQuality = nil,
	}
end

function PetFollowerRenderer:RemoveFollower(userId: number)
	local follower = self._followers[userId]
	if not follower then
		return
	end

	self:_destroyVisual(follower)
	self._followers[userId] = nil
	self._allowedRemoteUserIds[userId] = nil
end

function PetFollowerRenderer:Destroy()
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end

	for userId in self._followers do
		self:RemoveFollower(userId)
	end

	if self._renderFolder then
		self._renderFolder:Destroy()
		self._renderFolder = nil
	end
end

return PetFollowerRenderer
