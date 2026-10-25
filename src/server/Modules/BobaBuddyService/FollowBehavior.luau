--!strict
--[[
	FollowBehavior
	Smooth owner-following behavior for Boba Buddy instances.
	Utilizes Navigator (PathfindingService) to avoid getting stuck on obstacles, walls, and counters.
--]]

local Navigator = require(script.Parent.Navigator)

local FollowBehavior = {}

local FOLLOW_DISTANCE_MIN = 4
local FOLLOW_DISTANCE_MAX = 8
local TELEPORT_DISTANCE = 45
local FOLLOW_POLL_SECONDS = 0.1

function FollowBehavior.Start(model: Model, owner: Player, isBusy: () -> boolean): () -> ()
	local running = true
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- Disable collisions on limbs so buddy doesn't shove players or NPCs
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc ~= root then
			desc.CanCollide = false
		end
	end

	local lastPathComputeAt = 0

	task.spawn(function()
		while running and model.Parent do
			task.wait(FOLLOW_POLL_SECONDS)
			if not running or not model.Parent then
				break
			end

			if isBusy() then
				continue
			end

			local ownerChar = owner.Character
			local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not ownerRoot or not root or not humanoid then
				continue
			end

			local dist = (ownerRoot.Position - root.Position).Magnitude

			-- Teleport if too far (e.g. elevator, death, respawn, teleporters)
			if dist > TELEPORT_DISTANCE then
				local offset = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
				model:PivotTo(ownerRoot.CFrame * CFrame.new(offset))
				continue
			end

			-- Walk towards owner if beyond follow distance
			if dist > FOLLOW_DISTANCE_MAX then
				local function getFollowPosition(): Vector3
					local offset = root.Position - ownerRoot.Position
					local direction = if offset.Magnitude > 0.001 then offset.Unit else Vector3.zAxis
					return ownerRoot.Position + direction * FOLLOW_DISTANCE_MIN
				end

				local followPos = getFollowPosition()

				-- Check direct line of sight (skip expensive pathfinding if sightline is clear)
				local rayParams = RaycastParams.new()
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				rayParams.FilterDescendantsInstances = { model, ownerChar }
				local rayHit = workspace:Raycast(root.Position, (followPos - root.Position), rayParams)

				if not rayHit then
					humanoid:MoveTo(followPos)
				else
					local now = os.clock()
					if now - lastPathComputeAt >= 1.2 then
						lastPathComputeAt = now
						Navigator.WalkTo(model, followPos, {
							ArriveRadius = FOLLOW_DISTANCE_MAX,
							Timeout = 1.2,
							ShouldAbort = function()
								if not running or not model.Parent or isBusy() or not ownerRoot.Parent then
									return true
								end
								local newDist = (ownerRoot.Position - root.Position).Magnitude
								return newDist <= FOLLOW_DISTANCE_MAX or newDist > TELEPORT_DISTANCE
							end,
							WaypointRadius = 2.5,
						})
					end
				end
			elseif dist < FOLLOW_DISTANCE_MIN then
				-- Close enough: idle
				humanoid:MoveTo(root.Position)
			end
		end
	end)

	return function()
		running = false
	end
end

return FollowBehavior
