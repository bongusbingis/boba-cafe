--!strict
--[[
	Module: PassToolService
	Description: Gamepass tools and the Emote Pack (REVIVAL-001 PASS-PORT lane D).
	             Mop Whack (40973940) and Flying Mop (219651106) owners get their
	             tool in the Backpack on every spawn; Emote Pack (219651061) owners
	             get the live game's eight dances in the Roblox emote menu.

	             Ownership is PerkService:HasPerk. A purchase made this session is
	             granted at once (PromptGamePassPurchaseFinished -> GrantPassToCache).
	             The tools carry PassTool = "MopWhack" | "FlyingMop" and BuiltBy; they
	             have no kitchen attributes, so ordering/serving ignores them, and
	             nothing here touches the Boba Phone, clock-in or the spill mop.

	             Mop Whack: ToolsStorage["Mop Whack"] (dev place). Its legacy Animate
	             script is dropped and the swing is handled here (ragdoll + launch).
	             Flying Mop: needs ReplicatedStorage.SharedStorage.CharacterStorage
	             .FlyingMop (+ FM_Animation), authored in the live place only; with
	             them missing it warns once and the tool is not granted. The flight
	             itself is FlyingMopController (client).
--]]

---> services

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies

local Knit = require(Packages.Knit)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local PassCatalog = require(Shared.Configuration.PassCatalog)
local PassTools = require(Shared.Configuration.PassTools)
local WhackTarget = require(Shared.Utility.WhackTarget)
local WorldPath = require(Shared.Utility.WorldPath)

---> constants

local TOOLS_STORAGE_NAME = "ToolsStorage"
local ASSET_TIMEOUT_SECONDS = 10
local KIND_MOP_WHACK = "MopWhack"
local KIND_FLYING_MOP = "FlyingMop"
local KIND_PUMPKIN_LAUNCHER = "PumpkinLauncher"
local PASS_TOOL_ATTRIBUTE = PassTools.PassToolAttribute

---> service

local PassToolService = Knit.CreateService({
	Name = "PassToolService",
	Client = {},

	_warned = {} :: { [string]: boolean },
	_ragdollToken = {} :: { [Model]: number },
})

---> private

function PassToolService:_warnOnce(message: string)
	if not self._warned[message] then
		self._warned[message] = true
		warn(`[PassToolService] {message}`)
	end
end

local function findPassTool(container: Instance?, kind: string): Tool?
	if container == nil then
		return nil
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute(PASS_TOOL_ATTRIBUTE) == kind then
			return child
		end
	end
	return nil
end

local function hasTool(player: Player, kind: string): boolean
	return findPassTool(player:FindFirstChildOfClass("Backpack"), kind) ~= nil
		or findPassTool(player.Character, kind) ~= nil
end

local function mark(tool: Tool, kind: string)
	tool:SetAttribute(PASS_TOOL_ATTRIBUTE, kind)
	tool:SetAttribute("BuiltBy", PassTools.BuiltBy)
end

local function aliveRoot(character: Model?): (Humanoid?, BasePart?)
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

---> mop whack

-- Limp + launch the victim for a few seconds. The server owns the physics meanwhile
-- so the launch is not overridden by the victim's client.
function PassToolService:_ragdoll(character: Model, direction: Vector3)
	local humanoid, root = aliveRoot(character)
	if humanoid == nil or root == nil then
		return
	end
	local config = PassTools.MopWhack
	local token = (self._ragdollToken[character] or 0) + 1
	self._ragdollToken[character] = token

	humanoid.PlatformStand = true
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	root.AssemblyLinearVelocity = direction * config.LaunchHorizontal + Vector3.new(0, config.LaunchUp, 0)
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))

	task.delay(config.RagdollSeconds, function()
		if self._ragdollToken[character] ~= token then
			return -- hit again; the newer ragdoll restores
		end
		self._ragdollToken[character] = nil
		if character.Parent == nil then
			return
		end
		pcall(function()
			root:SetNetworkOwnershipAuto()
		end)
		if humanoid.Health > 0 then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

function PassToolService:_swing(player: Player, tool: Tool, animation: Animation?)
	local config = PassTools.MopWhack
	local character = player.Character
	local humanoid, root = aliveRoot(character)
	if humanoid == nil or root == nil or tool.Parent ~= character then
		return
	end

	tool.Enabled = false
	if animation ~= nil then
		pcall(function()
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				animator:LoadAnimation(animation):Play()
			end
		end)
	end

	task.wait(config.ImpactDelaySeconds)

	local victimCharacter: Model? = nil
	local look = root.CFrame.LookVector
	if tool.Parent == character and humanoid.Health > 0 then
		local candidates: { WhackTarget.Candidate } = {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local otherHumanoid, otherRoot = aliveRoot(other.Character)
				if otherHumanoid ~= nil and otherRoot ~= nil and not otherHumanoid.Sit then
					table.insert(candidates, { Key = other, Position = otherRoot.Position })
				end
			end
		end
		local victim = WhackTarget.Pick(root.Position, look, candidates, config.RangeStuds, config.MinFacingDot)
		if victim ~= nil then
			victimCharacter = (victim :: Player).Character
		end
	end

	if victimCharacter == nil then
		task.wait(config.MissCooldownSeconds)
		if tool.Parent ~= nil then
			tool.Enabled = true
		end
		return
	end

	local flatLook = Vector3.new(look.X, 0, look.Z)
	self:_ragdoll(victimCharacter, if flatLook.Magnitude > 1e-3 then flatLook.Unit else Vector3.zero)

	for remaining = config.HitCooldownSeconds, 1, -1 do
		if tool.Parent == nil then
			return
		end
		tool.Name = `{config.ToolName} ({remaining})`
		task.wait(1)
	end
	if tool.Parent ~= nil then
		tool.Name = config.ToolName
		tool.Enabled = true
	end
end

function PassToolService:_buildMopWhack(): Tool?
	local storage = ReplicatedStorage:WaitForChild(TOOLS_STORAGE_NAME, ASSET_TIMEOUT_SECONDS)
	local template = if storage then storage:FindFirstChild(PassTools.MopWhack.ToolName) else nil
	if template == nil or not template:IsA("Tool") then
		self:_warnOnce(
			`ReplicatedStorage.{TOOLS_STORAGE_NAME}["{PassTools.MopWhack.ToolName}"] is missing; Mop Whack not granted.`
		)
		return nil
	end
	local tool = template:Clone()
	-- The legacy Animate script needs old modules; keep only its swing animation.
	local legacy = tool:FindFirstChild("Animate")
	local found = if legacy then legacy:FindFirstChild("ActionAnimation") else nil
	local animation: Animation? = nil
	if found and found:IsA("Animation") then
		found.Parent = tool
		animation = found
	end
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end
	tool.CanBeDropped = false
	tool.Enabled = true
	mark(tool, KIND_MOP_WHACK)

	local swinging = false
	tool.Activated:Connect(function()
		if swinging or not tool.Enabled then
			return
		end
		local owner = Players:GetPlayerFromCharacter(tool.Parent)
		if owner == nil then
			return
		end
		swinging = true
		self:_swing(owner, tool, animation)
		swinging = false
	end)
	return tool
end

---> flying mop

function PassToolService:_flyingModel(): BasePart?
	local config = PassTools.FlyingMop
	local folder = WorldPath.waitFor(ReplicatedStorage, config.StoragePath, ASSET_TIMEOUT_SECONDS)
	local model = if folder then folder:FindFirstChild(config.MopModelName) else nil
	if model == nil or not model:IsA("BasePart") then
		self:_warnOnce(
			`ReplicatedStorage.{table.concat(config.StoragePath, ".")}.{config.MopModelName} is missing (live-place asset); Flying Mop not granted.`
		)
		return nil
	end
	return model
end

function PassToolService:_createMop(character: Model)
	local config = PassTools.FlyingMop
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") or character:FindFirstChild(config.MopCharacterName) then
		return
	end
	local folder = WorldPath.find(ReplicatedStorage, config.StoragePath)
	local template = if folder then folder:FindFirstChild(config.MopModelName) else nil
	if template == nil or not template:IsA("BasePart") then
		return
	end

	local mop = template:Clone()
	mop.Name = config.MopCharacterName
	mop.Massless = true
	mop.CanCollide = false
	local motor = Instance.new("Motor6D")
	motor.Part0 = root
	motor.Part1 = mop
	motor.C0 = config.MopC0
	motor.Parent = mop
	mop.Parent = character

	local swirl = mop:FindFirstChild("Swirl")
	local swirlEmitter = if swirl then swirl:FindFirstChildOfClass("ParticleEmitter") else nil
	if swirlEmitter then
		swirlEmitter.Enabled = true
		task.delay(config.SwirlSeconds, function()
			swirlEmitter.Enabled = false
		end)
	end
	task.delay(config.FadeInDelaySeconds, function()
		if mop.Parent ~= nil then
			TweenService:Create(mop, TweenInfo.new(config.FadeInSeconds), { Transparency = 0 }):Play()
		end
	end)
end

-- The mop is visible while the Flying Mop tool is in the character (equipped).
function PassToolService:_watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute(PASS_TOOL_ATTRIBUTE) == KIND_FLYING_MOP then
			self:_createMop(character)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute(PASS_TOOL_ATTRIBUTE) == KIND_FLYING_MOP then
			local mop = character:FindFirstChild(PassTools.FlyingMop.MopCharacterName)
			if mop then
				mop:Destroy()
			end
		end
	end)
	if findPassTool(character, KIND_FLYING_MOP) then
		self:_createMop(character)
	end
end

function PassToolService:_buildFlyingMop(): Tool?
	if self:_flyingModel() == nil then
		return nil
	end
	local tool = Instance.new("Tool")
	tool.Name = PassTools.FlyingMop.ToolName
	tool.CanBeDropped = false
	tool.RequiresHandle = false
	mark(tool, KIND_FLYING_MOP)
	return tool
end

function PassToolService:_buildPumpkinLauncher(): Tool?
	local storage = ReplicatedStorage:WaitForChild(TOOLS_STORAGE_NAME, ASSET_TIMEOUT_SECONDS)
	local template = if storage then storage:FindFirstChild(PassTools.PumpkinLauncher.ToolName) else nil
	if template == nil or not template:IsA("Tool") then
		self:_warnOnce(
			`ReplicatedStorage.{TOOLS_STORAGE_NAME}["{PassTools.PumpkinLauncher.ToolName}"] is missing; Pumpkin Launcher not granted.`
		)
		return nil
	end
	local tool = template:Clone()
	tool.CanBeDropped = false
	mark(tool, KIND_PUMPKIN_LAUNCHER)
	return tool
end

---> emotes

-- Adds the Emote Pack emotes to the character's HumanoidDescription so the Roblox
-- emote menu lists them. Not ApplyDescription: that resets clothing (UniformService)
-- and reloads the avatar.
function PassToolService:_applyEmotes(player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end
	local description = humanoid:FindFirstChildOfClass("HumanoidDescription")
		or humanoid:WaitForChild("HumanoidDescription", 10)
	if description == nil or not description:IsA("HumanoidDescription") then
		self:_warnOnce("Humanoid has no HumanoidDescription; Emote Pack emotes not added.")
		return
	end

	local emotes = description:GetEmotes()
	local equipped = {}
	for slot, emote in PassTools.Emotes do
		emotes[emote.Name] = { emote.AnimationId }
		equipped[slot] = emote.Name
	end
	description:SetEmotes(emotes)
	description:SetEquippedEmotes(equipped)
end

function PassToolService:_grantEmotes(player: Player)
	if Knit.GetService("PerkService"):HasPerk(player, PassTools.EmotePackPerk) and player.Parent ~= nil then
		self:_applyEmotes(player)
	end
end

---> grant

function PassToolService:_grant(player: Player)
	local perks = Knit.GetService("PerkService")
	local wantsMop = perks:HasPerk(player, PassTools.MopWhackPerk)
	local wantsFlying = perks:HasPerk(player, PassTools.FlyingMopPerk)
	local wantsPumpkin = perks:HasPerk(player, PassTools.PumpkinLauncherPerk)
	if player.Parent == nil then
		return
	end

	if wantsMop or wantsFlying or wantsPumpkin then
		local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
		if backpack ~= nil then
			if wantsMop and not hasTool(player, KIND_MOP_WHACK) then
				local tool = self:_buildMopWhack()
				if tool then
					tool.Parent = backpack
				end
			end
			if wantsFlying and not hasTool(player, KIND_FLYING_MOP) then
				local tool = self:_buildFlyingMop()
				if tool then
					tool.Parent = backpack
				end
			end
			if wantsPumpkin and not hasTool(player, KIND_PUMPKIN_LAUNCHER) then
				local tool = self:_buildPumpkinLauncher()
				if tool then
					tool.Parent = backpack
				end
			end
		end
	end
	self:_grantEmotes(player)
end

function PassToolService:_watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		self:_watchCharacter(character)
		task.spawn(self._grant, self, player)
	end)
	-- Avatar loading can swap the HumanoidDescription after spawn; re-add the emotes.
	player.CharacterAppearanceLoaded:Connect(function()
		task.spawn(self._grantEmotes, self, player)
	end)
	if player.Character then
		self:_watchCharacter(player.Character)
		task.spawn(self._grant, self, player)
	end
end

---> lifecycle

function PassToolService:PlayerAdded(player: Player)
	self:_watch(player)
end

function PassToolService:PlayerRemoving(player: Player)
	if player.Character then
		self._ragdollToken[player.Character] = nil
	end
end

function PassToolService:KnitStart()
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
			for _, perk in
				{
					PassTools.MopWhackPerk,
					PassTools.FlyingMopPerk,
					PassTools.EmotePackPerk,
					PassTools.PumpkinLauncherPerk,
				}
			do
				if entry and table.find(entry.Perks, perk) ~= nil then
					relevant = true
				end
			end
			if not relevant then
				return
			end
			pcall(function()
				(GamepassUtil :: any):GrantPassToCache(player, passId)
			end)
			task.spawn(self._grant, self, player)
		end
	)
end

return PassToolService
