--!strict
--[[
	Navigator
	Pathfinding helper for Boba Buddy instances utilizing PathfindingService.
	Navigates around obstacles, walls, and cafe counters (matching Customer NPC pathfinding).
--]]

local PathfindingService = game:GetService("PathfindingService")

local PATHFINDING_OPTIONS = {
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = false,
	WaypointSpacing = 4,
}

local ARRIVE_RADIUS_STUDS = 3.5
local WALK_POLL_SECONDS = 0.1

local Navigator = {}

export type NavigateOptions = {
	ArriveRadius: number?,
	Timeout: number?,
	ShouldAbort: (() -> boolean)?,
}

function Navigator.WalkTo(model: Model, targetPos: Vector3, options: NavigateOptions?): boolean
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return false
	end

	local arriveRadius = (options and options.ArriveRadius) or ARRIVE_RADIUS_STUDS
	local shouldAbort = options and options.ShouldAbort

	local start = root.Position
	local flatOffset = (start - targetPos) * Vector3.new(1, 0, 1)
	if flatOffset.Magnitude <= arriveRadius then
		return true
	end

	local path = PathfindingService:CreatePath(PATHFINDING_OPTIONS)
	local okCompute = pcall(function()
		path:ComputeAsync(start, targetPos)
	end)

	local waypoints = if okCompute and path.Status == Enum.PathStatus.Success then path:GetWaypoints() else nil

	-- If pathfinding failed or returned <= 1 waypoint, fallback to direct MoveTo
	if not waypoints or #waypoints <= 1 then
		humanoid:MoveTo(targetPos)
		local finished = false
		local moveConn
		moveConn = humanoid.MoveToFinished:Connect(function()
			finished = true
		end)

		local maxWait = (options and options.Timeout) or 5
		local deadline = os.clock() + maxWait
		while not finished and os.clock() < deadline and model.Parent do
			if shouldAbort and shouldAbort() then
				break
			end
			local currentFlat = ((root.Position - targetPos) * Vector3.new(1, 0, 1)).Magnitude
			if currentFlat <= arriveRadius then
				break
			end
			task.wait(WALK_POLL_SECONDS)
		end
		if moveConn then
			moveConn:Disconnect()
		end
		return ((root.Position - targetPos) * Vector3.new(1, 0, 1)).Magnitude <= arriveRadius
	end

	-- Follow waypoints smoothly
	for i = 2, #waypoints do
		if not model.Parent then
			return false
		end
		if shouldAbort and shouldAbort() then
			return false
		end

		local wp = waypoints[i]
		local wpPos = wp.Position
		local finished = false

		local conn = humanoid.MoveToFinished:Connect(function()
			finished = true
		end)

		humanoid:MoveTo(wpPos)
		if wp.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end

		local dist = (root.Position - wpPos).Magnitude
		local timeout = math.max(1.5, (dist / math.max(humanoid.WalkSpeed, 1)) * 3)
		local deadline = os.clock() + timeout

		while not finished and os.clock() < deadline and model.Parent do
			if shouldAbort and shouldAbort() then
				break
			end
			local flatDist = ((root.Position - wpPos) * Vector3.new(1, 0, 1)).Magnitude
			-- Early advance to next waypoint if close enough
			if i < #waypoints and flatDist <= arriveRadius then
				break
			end
			task.wait(WALK_POLL_SECONDS)
		end
		conn:Disconnect()
	end

	local finalDist = ((root.Position - targetPos) * Vector3.new(1, 0, 1)).Magnitude
	return finalDist <= arriveRadius
end

return Navigator
