--[[
    Module: RagdollUtil
    Description: Temporarily ragdolls a character by disabling its Motor6Ds and replacing
    each joint with a BallSocketConstraint, then restoring everything after a delay.

    Server-side only in practice: the constraints must replicate for other players to see
    the ragdoll.
--]]

---> module declaration
local RagdollUtil = {}

---> state

-- Characters currently ragdolled. Prevents re-entrant ragdolls, which would capture the
-- already-zeroed HipHeight as the "original" and leave the character permanently prone.
local active: { [Model]: boolean } = {}

---> constants
local COLLISION_PART_SIZE = Vector3.new(0.3, 0.3, 0.3)
local DEFAULT_RECOVER_AFTER = 1

---> public

--- Ragdolls `character` for `recoverAfter` seconds. Returns false when the character is
--- already ragdolled or is not in a ragdollable state.
function RagdollUtil:Ragdoll(character: Model, recoverAfter: number?): boolean
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return false
	end

	local originalHipHeight = humanoid.HipHeight

	-- A HipHeight of 0 means the character is already ragdolled or is an R6 rig this
	-- utility does not support.
	if active[character] or originalHipHeight == 0 then
		return false
	end

	active[character] = true
	humanoid.RequiresNeck = false

	local createdInstances: { Instance } = {}

	for _, motor in character:GetDescendants() do
		if not motor:IsA("Motor6D") then
			continue
		end

		local part0, part1 = motor.Part0, motor.Part1
		if not part0 or not part1 or not motor.Parent then
			continue
		end

		local attachment0 = Instance.new("Attachment")
		attachment0.CFrame = motor.C0
		attachment0.Parent = part0

		local attachment1 = Instance.new("Attachment")
		attachment1.CFrame = motor.C1
		attachment1.Parent = part1

		local socket = Instance.new("BallSocketConstraint")
		socket.Attachment0 = attachment0
		socket.Attachment1 = attachment1
		socket.LimitsEnabled = true
		socket.TwistLimitsEnabled = true
		socket.Parent = motor.Parent

		-- Small invisible collider so limbs do not sink through the floor.
		local collisionPart = Instance.new("Part")
		collisionPart.Transparency = 1
		collisionPart.Size = COLLISION_PART_SIZE
		collisionPart.Position = (motor.Parent :: BasePart).Position
		collisionPart.Parent = motor

		local collisionWeld = Instance.new("WeldConstraint")
		collisionWeld.Part0 = collisionPart
		collisionWeld.Part1 = motor.Parent :: BasePart
		collisionWeld.Parent = collisionPart

		motor.Enabled = false

		table.insert(createdInstances, collisionPart)
		table.insert(createdInstances, attachment0)
		table.insert(createdInstances, attachment1)
		table.insert(createdInstances, socket)

		-- Yield a frame between joints; converting them all at once tends to make the
		-- physics solver fling the character.
		task.wait()
	end

	humanoid.HipHeight = 0

	task.delay(recoverAfter or DEFAULT_RECOVER_AFTER, function()
		for _, instance in createdInstances do
			instance:Destroy()
		end

		for _, motor in character:GetDescendants() do
			if motor:IsA("Motor6D") then
				motor.Enabled = true
			end
		end

		if humanoid.Parent then
			humanoid.HipHeight = originalHipHeight
			humanoid.RequiresNeck = true
		end

		active[character] = nil
	end)

	return true
end

--- Whether `character` is currently ragdolled.
function RagdollUtil:IsRagdolled(character: Model): boolean
	return active[character] == true
end

return RagdollUtil
