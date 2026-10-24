--!strict
--[[
	FollowBehavior
	Smooth owner-following behavior for Boba Buddy instances.
--]]

local FollowBehavior = {}

local FOLLOW_DISTANCE_MIN = 4
local FOLLOW_DISTANCE_MAX = 8
local TELEPORT_DISTANCE = 45

function FollowBehavior.Start(model: Model, owner: Player, isBusy: () -> boolean): () -> ()
	local running = true
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")

	-- Disable collisions on limbs so buddy doesn't shove players or NPCs
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc ~= root then
			desc.CanCollide = false
		end
	end

	task.spawn(function()
		while running and model.Parent do
			task.wait(0.3)
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
				local direction = (root.Position - ownerRoot.Position).Unit
				local targetPos = ownerRoot.Position + direction * FOLLOW_DISTANCE_MIN
				humanoid:MoveTo(targetPos)
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
