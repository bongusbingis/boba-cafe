--!strict
--[[
	Module: CounterLock
	Description: Pure rules for real players ordering at the counter (REVIVAL-001
	             ORDER-FLOW-REWORK, DEC-059). No instances are created or read here, so
	             the rules are testable with plain values (tested in CustomerService.spec.luau).

	A clocked-out player standing alone in a register's CustomerArea, with no NPC at or
	queued for that register and no open order, is a counter customer. Baristas see a
	"Take Order" prompt on them. The first eligible barista to trigger it takes a lock;
	while the lock holds, only that barista can submit, and the prompt is hidden for
	everyone else. The lock ends on submit, cancel (tablet closed), timeout, either
	player leaving, the taker moving away, or a clock-state change.
--]]

local CounterLock = {}

-- TUNING (agent-set, Jack to tune): how long a barista holds a counter customer.
CounterLock.LOCK_SECONDS = 90
-- Slack in studs on the CustomerArea's thin (depth) axis, so a player standing at the
-- register but just outside the 2-stud box still counts.
CounterLock.DEPTH_MARGIN = 1.5
-- A CustomerArea belongs to the NPC Counter spot whose XZ is within this distance.
CounterLock.SPOT_MATCH_STUDS = 3

export type Lock = {
	Taker: any, -- the barista (Player at runtime)
	Id: number, -- unique per lock; a stale tablet's cancel names an older Id
	Expires: number, -- os.clock() deadline
}

-- True when `position` is inside the box (`cframe`, `size`), with `margin` studs of
-- slack on the local Z (depth) axis.
function CounterLock.InArea(cframe: CFrame, size: Vector3, position: Vector3, margin: number): boolean
	local localPos = cframe:PointToObjectSpace(position)
	return math.abs(localPos.X) <= size.X / 2
		and math.abs(localPos.Y) <= size.Y / 2
		and math.abs(localPos.Z) <= size.Z / 2 + margin
end

-- Index of the counter position nearest `position` in XZ, if within `maxDistance`.
function CounterLock.MatchSpot(position: Vector3, counters: { Vector3 }, maxDistance: number): number?
	local best: number? = nil
	local bestDistance = maxDistance
	for index, counter in counters do
		local distance = Vector2.new(counter.X - position.X, counter.Z - position.Z).Magnitude
		if distance <= bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

-- The one player who can order at an area: exactly one occupant, no NPC there and no
-- open order. Otherwise nil.
function CounterLock.EligibleCustomer<T>(occupants: { T }, npcPresent: boolean, hasOpenOrder: (T) -> boolean): T?
	if #occupants ~= 1 or npcPresent then
		return nil
	end
	local customer = occupants[1]
	if hasOpenOrder(customer) then
		return nil
	end
	return customer
end

-- True when the lock is held and not yet expired.
function CounterLock.IsHeld(lock: Lock?, now: number): boolean
	return lock ~= nil and now < lock.Expires
end

-- Whether `taker` may take the customer now: the lock is free, expired, or theirs.
function CounterLock.CanTake(lock: Lock?, taker: any, now: number): boolean
	return not CounterLock.IsHeld(lock, now) or (lock :: Lock).Taker == taker
end

-- A new lock for `taker`.
function CounterLock.Take(taker: any, id: number, now: number, seconds: number?): Lock
	return { Taker = taker, Id = id, Expires = now + (seconds or CounterLock.LOCK_SECONDS) }
end

-- True when `taker` holds this exact lock (same Id) and it has not expired.
function CounterLock.Holds(lock: Lock?, taker: any, id: any, now: number): boolean
	return CounterLock.IsHeld(lock, now) and (lock :: Lock).Taker == taker and (lock :: Lock).Id == id
end

return CounterLock
