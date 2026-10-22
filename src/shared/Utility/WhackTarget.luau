--!strict
--[[
	WhackTarget
	Pure target pick for Mop Whack: the nearest candidate within range that the
	swinger is facing. No Instances, so it is unit-testable.
--]]

export type Candidate = {
	Key: any,
	Position: Vector3,
}

local WhackTarget = {}

-- Returns the chosen candidate's Key, or nil. Ignores height so a hit on a
-- stair or a tall character still lands.
function WhackTarget.Pick(
	origin: Vector3,
	look: Vector3,
	candidates: { Candidate },
	range: number,
	minDot: number
): any?
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 1e-3 then
		return nil
	end
	flatLook = flatLook.Unit

	local bestKey: any? = nil
	local bestDistance = range
	for _, candidate in candidates do
		local offset = candidate.Position - origin
		local flat = Vector3.new(offset.X, 0, offset.Z)
		local distance = flat.Magnitude
		if distance <= bestDistance then
			-- A victim practically on top of the swinger counts as facing.
			local facing = distance < 1 or flat.Unit:Dot(flatLook) >= minDot
			if facing then
				bestKey = candidate.Key
				bestDistance = distance
			end
		end
	end
	return bestKey
end

return WhackTarget
