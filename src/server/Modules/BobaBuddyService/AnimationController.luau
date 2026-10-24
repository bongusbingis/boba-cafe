--!strict
--[[
	AnimationController
	Server-authoritative R15 animation player for Boba Buddy NPC instances,
	reusing the customer NPC animation architecture from SharedStorage.NPCStorage.Animations.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldPath = require(Shared.Utility.WorldPath)

local AnimationController = {}

local animations: { [string]: Animation }? = nil
local warned = false

local function resolveAnimations(): { [string]: Animation }
	if animations ~= nil then
		return animations
	end

	local sharedStorage = ReplicatedStorage:FindFirstChild("SharedStorage")
	local found: { [string]: Animation } = {}
	local animFolder = WorldPath.find(sharedStorage, { "NPCStorage", "Animations" })
	if animFolder ~= nil then
		for _, name in { "Idle", "Run", "Wave" } do
			local anim = animFolder:FindFirstChild(name)
			if anim ~= nil and anim:IsA("Animation") then
				found[name] = anim
			end
		end
	elseif not warned then
		warned = true
		warn("[BobaBuddyService] SharedStorage.NPCStorage.Animations missing; companion animations skipped.")
	end

	animations = found
	return found
end

export type Controller = {
	PlayIdle: () -> (),
	PlayRun: () -> (),
	Stop: () -> (),
}

function AnimationController.Attach(model: Model): Controller
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return {
			PlayIdle = function() end,
			PlayRun = function() end,
			Stop = function() end,
		}
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local anims = resolveAnimations()
	local tracks: { [string]: AnimationTrack } = {}

	local function getTrack(name: string): AnimationTrack?
		if tracks[name] ~= nil then
			return tracks[name]
		end
		local anim = anims[name]
		if anim == nil or animator == nil then
			return nil
		end
		local ok, track = pcall(function()
			local t = (animator :: Animator):LoadAnimation(anim)
			t.Looped = true
			t.Priority = if name == "Run" then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Idle
			return t
		end)
		if ok and track then
			tracks[name] = track
			return track
		end
		return nil
	end

	local idleTrack = getTrack("Idle")
	local runTrack = getTrack("Run")

	local isRunning = false

	local function playIdle()
		if not isRunning then
			return
		end
		if runTrack and runTrack.IsPlaying then
			runTrack:Stop(0.15)
		end
		if idleTrack and not idleTrack.IsPlaying then
			idleTrack:Play(0.15)
		end
	end

	local function playRun()
		if not isRunning then
			return
		end
		if idleTrack and idleTrack.IsPlaying then
			idleTrack:Stop(0.15)
		end
		if runTrack and not runTrack.IsPlaying then
			runTrack:Play(0.15)
		end
	end

	isRunning = true
	playIdle()

	local runningConn = humanoid.Running:Connect(function(speed: number)
		if speed > 0.5 then
			playRun()
		else
			playIdle()
		end
	end)

	local moveDirConn = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if humanoid.MoveDirection.Magnitude > 0.1 then
			playRun()
		elseif humanoid.MoveDirection.Magnitude == 0 then
			playIdle()
		end
	end)

	local function stop()
		isRunning = false
		if runningConn then
			runningConn:Disconnect()
		end
		if moveDirConn then
			moveDirConn:Disconnect()
		end
		if idleTrack then
			idleTrack:Stop()
			idleTrack:Destroy()
		end
		if runTrack then
			runTrack:Stop()
			runTrack:Destroy()
		end
	end

	return {
		PlayIdle = playIdle,
		PlayRun = playRun,
		Stop = stop,
	}
end

return AnimationController
