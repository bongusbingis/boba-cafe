--!strict
--[[
	FlightController.luau
	Knit controller managing staff flight mode.
	Works with WASD, Space/LeftControl, and touch/mobile movement thumbstick.
]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> controller declaration
local FlightController = Knit.CreateController({
	Name = "FlightController",
})

FlightController._isFlying = false
FlightController._renderConnection = nil :: RBXScriptConnection?
FlightController._bodyGyro = nil :: BodyGyro?
FlightController._bodyVelocity = nil :: BodyVelocity?

function FlightController:SetFlying(enabled: boolean)
	local localPlayer = Players.LocalPlayer
	local char = localPlayer.Character
	if not char then
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end

	if enabled then
		if self._isFlying then
			return
		end
		self._isFlying = true

		local gyro = Instance.new("BodyGyro")
		gyro.Name = "FlyGyro"
		gyro.P = 9e4
		gyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
		gyro.CFrame = root.CFrame
		gyro.Parent = root
		self._bodyGyro = gyro

		local velo = Instance.new("BodyVelocity")
		velo.Name = "FlyVelocity"
		velo.P = 9e4
		velo.MaxForce = Vector3.new(9e9, 9e9, 9e9)
		velo.Velocity = Vector3.zero
		velo.Parent = root
		self._bodyVelocity = velo

		hum.PlatformStand = true

		local speed = 80
		self._renderConnection = RunService.RenderStepped:Connect(function()
			if not self._isFlying or not root or not root.Parent then
				self:SetFlying(false)
				return
			end

			local cam = workspace.CurrentCamera
			if not cam then
				return
			end

			local camCF = cam.CFrame
			gyro.CFrame = camCF

			local moveDir = hum.MoveDirection
			local vertical = 0
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				vertical += 1
			end
			if
				UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			then
				vertical -= 1
			end

			local targetVelo = Vector3.zero
			if moveDir.Magnitude > 0 then
				targetVelo = moveDir * speed
			end
			targetVelo += Vector3.new(0, vertical * speed, 0)

			velo.Velocity = targetVelo
		end)
	else
		if not self._isFlying then
			return
		end
		self._isFlying = false

		if self._renderConnection then
			self._renderConnection:Disconnect()
			self._renderConnection = nil
		end
		if self._bodyGyro then
			self._bodyGyro:Destroy()
			self._bodyGyro = nil
		end
		if self._bodyVelocity then
			self._bodyVelocity:Destroy()
			self._bodyVelocity = nil
		end
		if hum then
			hum.PlatformStand = false
		end
	end
end

function FlightController:KnitStart()
	local localPlayer = Players.LocalPlayer
	localPlayer.CharacterAdded:Connect(function()
		self:SetFlying(false)
	end)

	local ModerationService = Knit.GetService("ModerationService")
	ModerationService.FlightSignal:Connect(function(enabled: boolean)
		self:SetFlying(enabled)
	end)
end

return FlightController
