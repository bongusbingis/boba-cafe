---@diagnostic disable: 1000
---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sounds = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Animator = require(ReplicatedStorage.Shared.Utility.Animator)
local WorldPath = require(ReplicatedStorage.Shared.Utility.WorldPath)
local Knit = require(Packages.Knit)
local ReplicaController = require(Packages.ReplicaController)

---> assets
local LocalPlayer = Players.LocalPlayer

-- Resolved in KnitStart with a bounded wait (never at require time or in KnitInit, which would block other
-- controllers); nil when the place does not contain them. Spills then simply do not show their UI/animations.
local WORLD_WAIT_SECONDS = 10
local TRIP_MAX_SECONDS = 5 -- the trip always ends (controls back on) within this time
local Storage: Instance? = nil
local SpillsFolder: Instance? = nil

local BadgeService

--- Enables or disables the default character controls (replaces the removed SetCoreAndControls controller).
local function setControlsEnabled(enabled: boolean)
	local Ok, Err = pcall(function()
		local PlayerModule = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule", 5))
		local Controls = PlayerModule:GetControls()
		if enabled then
			Controls:Enable()
		else
			Controls:Disable()
		end
	end)
	if not Ok then
		warn("[SpillController] Could not toggle player controls:", Err)
	end
end

local SpillController = Knit.CreateController({
	Name = "SpillController",
	Tripped = false,
	Boards = {},
	ActiveTweens = {},
	Percent = nil :: number?,
})

local function playSfx(name: string)
	local Sfx = Sounds:FindFirstChild("SFX")
	local Sound = Sfx and Sfx:FindFirstChild(name)
	if Sound and Sound:IsA("Sound") then
		Sound:Play()
	end
end

function SpillController:_Trip()
	if self.Tripped or LocalPlayer:GetAttribute("CleaningSpill") then
		return
	end

	self.Tripped = true
	if BadgeService then
		BadgeService:AwardBadgeByName("Slipped")
	end
	playSfx("Trip_02")

	-- Controls go off after a short delay. `Recovered` stops that delayed disable from
	-- running after the trip has already ended, which would leave the player frozen.
	local Recovered = false
	task.delay(0.25, function()
		if Recovered then
			return
		end
		setControlsEnabled(false)
		playSfx("Trip_01")
	end)
	local Animation = self.Animation
	if Animation then
		Animation:Play()
		Animation:AdjustSpeed(1.5)
		local Deadline = os.clock() + TRIP_MAX_SECONDS
		while Animation.IsPlaying and os.clock() < Deadline do
			task.wait()
		end
	end
	Recovered = true
	setControlsEnabled(true)
	task.wait(1)

	self.Tripped = false
end

local function waitForAnimator(character: Model): Animator
	-- Character exists but Humanoid/Animator may not be parented yet
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		or character:WaitForChild("Humanoid", 10)
	assert(humanoid, "Humanoid not found in character")
	return humanoid:FindFirstChildWhichIsA("Animator")
		or humanoid:WaitForChild("Animator", 10)
end

function SpillController:_HandleAnimations()
	local fallingAnimation = Storage
		and Storage:FindFirstChild("Animations")
		and Storage.Animations:FindFirstChild("FallingAnimation")
	if not fallingAnimation then
		warn(
			"[SpillController] SharedStorage.Spills.Animations.FallingAnimation is missing; tripping animation disabled"
		)
		return
	end

	local function load(character: Model)
		waitForAnimator(character) -- ensure Animator exists before LoadAnimation
		self.Animation = Animator:LoadAnimation(character, fallingAnimation)
	end

	load(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
	LocalPlayer.CharacterAdded:Connect(load)
end

function SpillController:_NewSpillsReplica(Replica)
	Replica:ConnectOnClientEvent(
		function(
			Sign: Model,
			Data: {
				Time: number,
				EasingStyle: Enum.EasingStyle,
				EasingDirection: Enum.EasingDirection,
				Goal: { [string]: any },
			},
			Sound: string
		)
			if Sound then
				playSfx(Sound)
			end
			TweenService
				:Create(
					Sign,
					TweenInfo.new(
						Data.Time,
						Enum.EasingStyle[Data.EasingStyle],
						Enum.EasingDirection[Data.EasingDirection]
					),
					Data.Goal
				)
				:Play()
		end
	)
end

function SpillController:_NewCleanlinessReplica(Value)
	self.Percent = Value
	for _, Board in pairs(self.Boards) do
		local Bar = Board.Holder.Main.Progressbar.Content
		local Label = Board.Holder.Main.Progressbar.Label
		local GoalSize = UDim2.fromScale(Value / 100, 1)

		local Existing = self.ActiveTweens[Bar]
		if Existing then
			Existing.TotalTime += 0.125
			if Existing.Tween then
				Existing.Tween:Cancel()
			end
		else
			self.ActiveTweens[Bar] = {
				TotalTime = 0.25,
			}
		end

		local BarTween = TweenService:Create(
			Bar,
			TweenInfo.new(self.ActiveTweens[Bar].TotalTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Size = GoalSize }
		)
		self.ActiveTweens[Bar].Tween = BarTween
		BarTween:Play()

		BarTween.Completed:Connect(function()
			self.ActiveTweens[Bar].TotalTime = 0.25
		end)

		if Value >= 100 then
			Bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			Bar.Rainbow.Enabled = true
			Label.Text = `{Value}%`
		else
			Bar.BackgroundColor3 = Color3.fromRGB(132, 220, 0)
			Bar.Rainbow.Enabled = false
			Label.Text = `{Value}%`
		end
	end
end

function SpillController:_RenderBoard(Board)
	local Template = Storage and Storage:FindFirstChild("BoardInterface")
	if not Template then
		warn("[SpillController] SharedStorage.Spills.BoardInterface is missing; spill board UI disabled")
		return
	end

	local Gui = Template:Clone()
	Gui.ResetOnSpawn = false
	Gui.Parent = LocalPlayer.PlayerGui
	Gui.Adornee = Board:IsA("BasePart") and Board or Board.Screen


	-- local CleanButton = Knit.Controllers.UIElementController.new(Gui.Holder.Main.CleanButton, "ShadowButton")
	-- CleanButton.Activated:Connect(function()
	-- 	Knit.Controllers.RobuxPurchaseController:InitiateClientRobuxPurchase("Product", 3317052044, false)
	-- end)

	-- local SpawnButton = Knit.Controllers.UIElementController.new(Gui.Holder.Main.SpawnButton, "ShadowButton")
	-- SpawnButton.Activated:Connect(function()
	-- 	Knit.Controllers.RobuxPurchaseController:InitiateClientRobuxPurchase("Product", 3317051739, false)
	-- end)

	table.insert(self.Boards, Gui)
	if self.Percent then
		self:_NewCleanlinessReplica(self.Percent)
	end
end

function SpillController:KnitStart()
	local SpillService = Knit.GetService("SpillService")
	local BadgeOk, BadgeResult = pcall(Knit.GetService, "BadgeService")
	if BadgeOk then
		BadgeService = BadgeResult
	end

	-- Replicas and signals do not depend on the authored world, so connect them immediately.
	ReplicaController.ReplicaOfClassCreated("SpillsReplica", function(Replica)
		self:_NewSpillsReplica(Replica)
	end)

	ReplicaController.ReplicaOfClassCreated("CleanlinessReplica", function(Replica)
		self:_NewCleanlinessReplica(Replica.Data.Percent)
		Replica:ListenToChange({ "Percent" }, function(Value: number)
			self:_NewCleanlinessReplica(Value)
		end)
	end)

	SpillService.Trip:Connect(function()
		self:_Trip()
	end)

	LocalPlayer:GetAttributeChangedSignal("CleaningSpill"):Connect(function()
		setControlsEnabled(not LocalPlayer:GetAttribute("CleaningSpill"))
	end)

	-- Resolve the authored world on its own thread so a missing/late folder never blocks other controllers.
	task.spawn(function()
		local Deadline = os.clock() + WORLD_WAIT_SECONDS
		Storage = WorldPath.waitFor(ReplicatedStorage, { "SharedStorage", "Spills" }, Deadline - os.clock())
		SpillsFolder = WorldPath.waitFor(workspace, { "Assets", "Spills" }, Deadline - os.clock())
		if not Storage then
			warn("[SpillController] SharedStorage.Spills is missing; spill animations and boards disabled")
		end
		if not SpillsFolder then
			warn("[SpillController] workspace.Assets.Spills is missing; spill boards disabled")
		end

		self:_HandleAnimations()

		local Boards = SpillsFolder and WorldPath.waitFor(SpillsFolder, { "Boards" }, Deadline - os.clock())
		if not Boards then
			if SpillsFolder then
				warn("[SpillController] workspace.Assets.Spills.Boards is missing; spill boards disabled")
			end
			return
		end

		for _, Board in Boards:GetChildren() do
			self:_RenderBoard(Board)
		end
		Boards.ChildAdded:Connect(function(Board)
			self:_RenderBoard(Board)
		end)
	end)
end

return SpillController
