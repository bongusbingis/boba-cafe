--!strict
--[[
	FlyingMopController (REVIVAL-001 PASS-PORT lane D)
	Flight for the Flying Mop pass tool: while the tool (PassTool = "FlyingMop") is
	equipped the character hovers above the ground and glides toward the move
	direction, facing the camera yaw. Unequip, death or respawn ends it. Ported from
	the live game's FlyingMop controller (its constraint values and hover maths).
	The mop model itself is attached by PassToolService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local PassTools = require(Shared.Configuration.PassTools)
local WorldPath = require(Shared.Utility.WorldPath)

local FlyingMopController = Knit.CreateController({
	Name = "FlyingMopController",
})

local KIND = "FlyingMop"
local POSE_SPEED = 2
local POSE_FREEZE_SECONDS = 0.75

local function isFlyingTool(instance: Instance): boolean
	return instance:IsA("Tool") and instance:GetAttribute(PassTools.PassToolAttribute) == KIND
end

function FlyingMopController:KnitStart()
	local config = PassTools.FlyingMop
	local player = Players.LocalPlayer
	local stopFlight: (() -> ())? = nil

	local function stop()
		if stopFlight then
			stopFlight()
			stopFlight = nil
		end
	end

	local function start(character: Model)
		stop()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if humanoid == nil or root == nil or not root:IsA("BasePart") then
			return
		end

		local attachment = Instance.new("Attachment")
		attachment.Name = "FlyingMopAttachment"
		attachment.Parent = root
		attachment.WorldPosition = root.Position

		-- Values copied from the live game's FM_AlignOrientation / FM_AlignPosition.
		local alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.Attachment0 = attachment
		alignOrientation.MaxTorque = 100000
		alignOrientation.MaxAngularVelocity = 10000
		alignOrientation.Responsiveness = 25
		alignOrientation.RigidityEnabled = false
		alignOrientation.Parent = root

		local alignPosition = Instance.new("AlignPosition")
		alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
		alignPosition.Attachment0 = attachment
		alignPosition.MaxForce = 10000
		alignPosition.MaxVelocity = 100
		alignPosition.Responsiveness = 25
		alignPosition.RigidityEnabled = false
		alignPosition.ApplyAtCenterOfMass = true
		alignPosition.Parent = root

		local track: AnimationTrack? = nil
		local storage = WorldPath.find(ReplicatedStorage, config.StoragePath)
		local animation = if storage then storage:FindFirstChild(config.AnimationName) else nil
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animation and animation:IsA("Animation") and animator then
			local loaded = animator:LoadAnimation(animation)
			loaded.Priority = Enum.AnimationPriority.Action
			loaded:Play()
			loaded:AdjustSpeed(POSE_SPEED)
			task.delay(POSE_FREEZE_SECONDS, function()
				if loaded.IsPlaying then
					loaded:AdjustSpeed(0) -- hold the riding pose
				end
			end)
			track = loaded
		end

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { character }

		local goal = attachment.WorldPosition
		local connection = RunService.Heartbeat:Connect(function(deltaTime: number)
			local camera = workspace.CurrentCamera
			if camera == nil or root.Parent == nil then
				return
			end
			local _, yaw, _ = camera.CFrame:ToOrientation()
			alignOrientation.CFrame = CFrame.Angles(0, yaw, 0)

			local target = root.Position + humanoid.MoveDirection * config.MoveReach
			goal = goal:Lerp(target, config.LerpAlpha)
			attachment.WorldPosition = goal

			local bob = math.sin(os.clock()) / config.BobDivisor
			local origin = root.Position
				+ Vector3.new(0, config.HoverHeight, 0)
				+ root.AssemblyLinearVelocity * deltaTime
			local hit = workspace:Raycast(origin, Vector3.new(0, config.RayDown, 0), raycastParams)
			local y = if hit then hit.Position.Y + bob + config.HoverHeight else bob + config.HoverHeight
			alignPosition.Position = Vector3.new(goal.X, y, goal.Z)
		end)

		stopFlight = function()
			connection:Disconnect()
			if track then
				track:Stop()
				track:Destroy()
			end
			alignOrientation:Destroy()
			alignPosition:Destroy()
			attachment:Destroy()
		end
	end

	local function watch(character: Model)
		character.ChildAdded:Connect(function(child)
			if isFlyingTool(child) then
				start(character)
			end
		end)
		character.ChildRemoved:Connect(function(child)
			if isFlyingTool(child) then
				stop()
			end
		end)
		for _, child in character:GetChildren() do
			if isFlyingTool(child) then
				start(character)
			end
		end
	end

	player.CharacterRemoving:Connect(stop)
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

return FlyingMopController
