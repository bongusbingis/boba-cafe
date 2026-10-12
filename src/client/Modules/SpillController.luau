---@diagnostic disable: 1000
---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sounds = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Animator = require(ReplicatedStorage.Shared.Utility.Animator)
local Knit = require(Packages.Knit)
local ReplicaController = require(Packages.ReplicaController)

---> assets
local LocalPlayer = Players.LocalPlayer

local Storage = ReplicatedStorage.SharedStorage.Spills
local SpillsFolder = workspace.Assets.Spills

local BadgeService

local SpillController = Knit.CreateController({
	Name = "SpillController",
	Tripped = false,
	Boards = {},
	ActiveTweens = {},
})

function SpillController:_Trip()
	if self.Tripped or LocalPlayer:GetAttribute("CleaningSpill") then
		return
	end

	self.Tripped = true
	BadgeService:AwardBadgeByName("Slipped")
	Sounds.SFX.Trip_02:Play()

	task.delay(0.25, function()
		Knit.Controllers.SetCoreAndControls:SetPlayerControlsEnabled(false)
		Sounds.SFX.Trip_01:Play()
	end)
	self.Animation:Play()
	self.Animation:AdjustSpeed(1.5)
	self.Animation.Stopped:Wait()
	Knit.Controllers.SetCoreAndControls:SetPlayerControlsEnabled(true)
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
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	waitForAnimator(character) -- ensure Animator exists before LoadAnimation
	self.Animation = Animator:LoadAnimation(character, Storage.Animations.FallingAnimation)

	LocalPlayer.CharacterAdded:Connect(function(newCharacter)
		waitForAnimator(newCharacter)
		self.Animation = Animator:LoadAnimation(newCharacter, Storage.Animations.FallingAnimation)
	end)
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
				Sounds.SFX[Sound]:Play()
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
			Label.Text = `Boost Active!`
		else
			Bar.BackgroundColor3 = Color3.fromRGB(132, 220, 0)
			Bar.Rainbow.Enabled = false
			Label.Text = `{Value}%`
		end
	end
end

function SpillController:_RenderBoard(Board)
	local Gui = Storage.BoardInterface:Clone()
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
end

function SpillController:KnitStart()
	local SpillService = Knit.GetService("SpillService")
	BadgeService = Knit.GetService("BadgeService")

	self:_HandleAnimations()
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
		Knit.Controllers.SetCoreAndControls:SetPlayerControlsEnabled(not LocalPlayer:GetAttribute("CleaningSpill"))
	end)
end

function SpillController:KnitInit()
	for _, Board in SpillsFolder.Boards:GetChildren() do
		self:_RenderBoard(Board)
	end

	SpillsFolder.Boards.ChildAdded:Connect(function(Board)
		self:_RenderBoard(Board)
	end)
end

return SpillController
