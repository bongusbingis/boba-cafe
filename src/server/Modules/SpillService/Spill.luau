---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Utility = Shared.Utility

---> dependencies
local Knit = require(Packages.Knit)
local Config = require(Shared.Configuration.Spills) :: { [string]: any }

---> vars
-- The authored spill assets (SpillService.Storage / SpillService.SpillsFolder) are resolved by SpillService in
-- KnitStart, never at require time, and spills are only created once they exist.
local Zone = require(Packages.Zone)
local Janitor = require(Packages.Janitor)
local ReplicaService = require(Packages.ReplicaService)

local Animator = require(Utility.Animator)
local ItemFader = require(Utility.ItemFader)

local ANIMATION_LOAD_TIMEOUT_SECONDS = 3

-- Services are looked up on use. SpillService:KnitStart can build spills before
-- Knit.OnStart resolves, so module locals assigned there would still be nil.
local function Service(Name: string): any
	return Knit.GetService(Name)
end

local Spill = {}
Spill.__index = Spill

local SpillsReplica = ReplicaService.NewReplica({
	ClassToken = ReplicaService.NewClassToken("SpillsReplica"),
	Replication = "All",
})

function Spill.new(Type: string, Object: string, Region: BasePart, Bought: boolean)
	local self = setmetatable({}, Spill)

	self.Janitor = Janitor.new()
	self.Type = Type
	self._Object = Object
	self.Region = Region
	self.Bought = Bought
	self.Cleaning = false
	self.Destroyed = false

	-- Build failures clean up whatever was already created, then propagate so SpillService can react.
	local Ok, Err = pcall(self._Build, self)
	if not Ok then
		self.Destroyed = true
		self.Janitor:Cleanup()
		error(Err, 0)
	end

	return self
end

function Spill:_GenerateCFrame(): CFrame?
	local Position = self.Region.Position
	local Scale = self.Region.Size
	local Fitting = self.Object.PrimaryPart.Size

	local xExtent = math.max(0, (Scale.X / 2) - (Fitting.X / 2))
	local zExtent = math.max(0, (Scale.Z / 2) - (Fitting.Z / 2))

	if self.Region:IsA("MeshPart") and self.Region.MeshId == "rbxassetid://12365668326" then
		xExtent = math.max(0, xExtent - 0.5)
		zExtent = math.max(0, zExtent - 0.5)
	end

	return CFrame.new(
		Position
			+ Vector3.new(math.random(-zExtent, zExtent), Scale.Y / 2 + (Fitting.Y / 2), math.random(-xExtent, xExtent))
	) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
end

function Spill:_FindLocationWithinRegion()
	local RegionSpills = Service("SpillService").Spills[self.Type][self.Region]
	local MinDistance = Config.Min_Distance[self.Region.Name] or Config.Min_Distance.Floor

	for _ = 1, 5 do
		local NewCFrame = self:_GenerateCFrame()

		local Valid = true
		if RegionSpills and #RegionSpills >= 1 then
			for _, OtherSpill in pairs(RegionSpills) do
				if
					OtherSpill ~= self
					and (OtherSpill.Object:GetPivot().Position - NewCFrame.Position).Magnitude <= MinDistance
				then
					Valid = false
					break
				end
			end
		end

		if Valid then
			self.Object:PivotTo(NewCFrame)
			return
		end
	end

	self:Destroy()
end

function Spill:_GetCleaningTools(): (Instance, Instance)
	local Tools = Service("SpillService").Storage.Tools
	if self.Type == "Mopping" then
		return Tools.Mop:Clone(), Tools.MopBucket:Clone()
	else
		return Tools.SprayBottle:Clone(), Tools.DishTowel:Clone()
	end
end

function Spill:_GetAnimation(Player: Player): AnimationTrack
	if self.Type == "Mopping" then
		return Animator:LoadAnimation(Player.Character, self.Object.MoppingAnim.Value)
	else
		if self.Object.Animation.Value.Name == "TableAnimations" then
			return Animator:LoadAnimation(Player.Character, self.Object.Animation.Value[self.Region.Parent.Parent.Name])
		else
			return Animator:LoadAnimation(Player.Character, self.Object.Animation.Value)
		end
	end
end

function Spill:_LockPlayerMovement(Player)
	Player.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
	Player.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
	Player.Character.Humanoid.AutoRotate = false
end

function Spill:_UnlockPlayerMovement(Player)
	Player.DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice
	Player.DevTouchMovementMode = Enum.DevTouchMovementMode.UserChoice
	Player.Character.Humanoid.AutoRotate = true
end

function Spill:_FinishCleaning(Player: Player, AnimationTrack: AnimationTrack, RightTool: Instance, LeftTool: Instance)
	local Sparkles = Service("SpillService").Storage.Sparkles:Clone()
	Sparkles.Parent = self.Object.PrimaryPart
	Sparkles:Emit(30)
	AnimationTrack:Stop()

	local _itemFader = ItemFader.new()
	_itemFader:AddItem(LeftTool)
	_itemFader:AddItem(RightTool)
	_itemFader:AddItem(self.Object)
	_itemFader:FadeOut()

	self.Janitor:Add(Sparkles)
	self.Janitor:Add(_itemFader)

	self:_UnlockPlayerMovement(Player)
	Player:SetAttribute("CleaningSpill", nil)

	Service("CurrencyService"):Modify(Player, "Points", Config.PointIncrement)

	task.wait(1)
	self:Destroy()
end

function Spill:_RunCleaning(Player: Player)
	self.Cleaning = true
	Player:SetAttribute("CleaningSpill", true)
	self.Prompt.Enabled = false
	self.Janitor:LinkToInstance(Player.Character)

	local LookVector = (self.Object.PrimaryPart.CFrame + (self.Object.PrimaryPart.CFrame.LookVector * 2.5))
		* CFrame.Angles(0, math.rad(180), 0)

	self:_LockPlayerMovement(Player)

	if self.Type == "Mopping" then
		Player.Character:PivotTo(LookVector + Vector3.new(0, 3, 0))
	end

	local RightTool, LeftTool = self:_GetCleaningTools()
	local AnimationTrack = self:_GetAnimation(Player)

	self.Janitor:Add(AnimationTrack, "destroy")
	self.Janitor:Add(RightTool)
	self.Janitor:Add(LeftTool)

	AnimationTrack:AddItems(Player, {
		{
			Model = RightTool,
			Motor = {
				Part0 = RightTool,
				Part1 = Player.Character.RightHand,
				C0 = RightTool.Offset.Value,
			},
		},
		{
			Model = LeftTool,
			Motor = {
				Part0 = LeftTool,
				Part1 = if self.Type == "Mopping" then Player.Character.LeftFoot else Player.Character.LeftHand,
				C0 = LeftTool.Offset.Value,
			},
		},
	})

	AnimationTrack:Play()
	-- An animation that never loads (e.g. no asset permission) must not hold the cleaner;
	-- erroring here hands the player back through _RecoverFromFailedCleaning.
	local LoadDeadline = os.clock() + ANIMATION_LOAD_TIMEOUT_SECONDS
	while AnimationTrack.Length <= 0 do
		if os.clock() > LoadDeadline then
			AnimationTrack:Stop()
			RightTool:Destroy()
			LeftTool:Destroy()
			error("cleaning animation did not load", 0)
		end
		task.wait()
	end

	self.Janitor:Add(AnimationTrack:GetMarkerReachedSignal("Sound"):Connect(function(Value: string)
		if not AnimationTrack.Animation:FindFirstChild("SoundProfile") then
			return
		end
		AnimationTrack.Animation.SoundProfile[Value]:Play()
	end))

	task.wait(AnimationTrack.Length)
	self:_FinishCleaning(Player, AnimationTrack, RightTool, LeftTool)
end

--- Releases the player and re-arms the prompt after a cleaning attempt errored part way through.
function Spill:_RecoverFromFailedCleaning(Player: Player)
	pcall(self._UnlockPlayerMovement, self, Player)
	Player:SetAttribute("CleaningSpill", nil)
	self.Cleaning = false
	if not self.Destroyed and self.Prompt then
		self.Prompt.Enabled = true
	end
end

function Spill:_ListenToCleanPrompt()
	return self.Prompt.Triggered:Connect(function(Player)
		if Player:GetAttribute("CleaningSpill") or Player:GetAttribute("Restocking") or self.Cleaning then
			Service("DialogService"):Notify(Player, {
				Title = "Notification",
				Description = "You can't do that right now.",
			})
			return
		end

		if not Service("ShiftService"):IsClockedIn(Player) then
			return
		end

		local Ok, Err = pcall(self._RunCleaning, self, Player)
		if not Ok then
			warn(`[SpillService] Cleaning failed for {Player.Name}: {Err}`)
			self:_RecoverFromFailedCleaning(Player)
		end
	end)
end

function Spill:_ListenToSignPrompt()
	local InitialSignCFrame = self.Object.SignStartPosition.CFrame

	return self.SignPrompt.Triggered:Connect(function()
		self.SignPrompt.Enabled = false
		if self.Object.SignStartPosition.CFrame ~= self.Object.SignEndPosition.CFrame then
			return
		end

		SpillsReplica:FireAllClients(self.Object.SignStartPosition, {
			Time = 0.3,
			EasingStyle = "Quad",
			EasingDirection = "Out",
			Goal = { CFrame = InitialSignCFrame },
		}, "Pop_01")

		task.wait(0.3)
		self.Object.SignStartPosition.CFrame = InitialSignCFrame
	end)
end

function Spill:_ListenToPlayerTrip()
	local TripZone = Zone.new(self.Object.TripRegion)

	TripZone.playerEntered:Connect(function(Player: Player)
		if self.Cleaning or Player:GetAttribute("CleaningSpill") then
			return
		end

		Service("SpillService").Client.Trip:Fire(Player)
		SpillsReplica:FireAllClients(self.Object.SignStartPosition, {
			Time = 0.6,
			EasingStyle = "Bounce",
			EasingDirection = "Out",
			Goal = { CFrame = self.Object.SignEndPosition.CFrame },
		})

		task.wait(0.6)
		self.Object.SignStartPosition.CFrame = self.Object.SignEndPosition.CFrame
		self.SignPrompt.Enabled = true
	end)

	return TripZone
end

function Spill:_Build()
	local SpillService = Service("SpillService")
	self.Object = SpillService.Storage.Spills[self._Object]:Clone()
	self.Object.Parent = SpillService.SpillsFolder.Active
	self.Janitor:Add(self.Object)

	if self._Object == "Boba" then
		self.Object.Liquid.BrickColor = BrickColor.random()
	end

	self.Prompt = Instance.new("ProximityPrompt")
	self.Prompt.Parent = self.Object.PrimaryPart
	self.Prompt.RequiresLineOfSight = false
	self.Prompt.HoldDuration = 1
	self.Prompt.ObjectText = "Spill"
	self.Prompt.ActionText = "Clean"
	self.Prompt.Name = "CleanSpillPrompt"

	self.Janitor:Add(self:_ListenToCleanPrompt())
	self:_FindLocationWithinRegion()

	if self.Type == "Mopping" then
		if not self.Object:FindFirstChild("SignStartPosition") then
			warn("Missing SignStartPosition for spill in region " .. self.Region.Name)
			return
		end
		self.Object:ScaleTo(1)
		self.SignPrompt = Instance.new("ProximityPrompt")
		self.SignPrompt.Parent = self.Object.SignStartPosition
		self.SignPrompt.RequiresLineOfSight = false
		self.SignPrompt.ObjectText = "Sign"
		self.SignPrompt.ActionText = "Fix"
		self.SignPrompt.Name = "FixSpillSignPrompt"
		self.SignPrompt.Enabled = false

		self.Object.SignStartPosition.Transparency = 0

		self.Janitor:Add(self:_ListenToSignPrompt())
		self.Janitor:Add(self:_ListenToPlayerTrip())
	end
end

function Spill:Clean()
	if self.Cleaning then
		return
	end

	self.Cleaning = true
	self.Prompt.Enabled = false

	local Sparkles = Service("SpillService").Storage.Sparkles:Clone()
	Sparkles.Parent = self.Object.PrimaryPart
	Sparkles:Emit(30)

	local _itemFader = ItemFader.new()
	_itemFader:AddItem(self.Object)
	_itemFader:FadeOut()

	self.Janitor:Add(Sparkles)
	self.Janitor:Add(_itemFader)

	task.wait(1.5)
	self:Destroy()
end

function Spill:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Janitor:Cleanup()
	Service("SpillService"):SpillCleaned(self)
end

return Spill
