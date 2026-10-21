--!strict
--[[
	Module: PourMeter
	Description: Pure logic for the station skill moment (REVIVAL-001 BIG-B7, DEC-058).

	After a pour station finishes, the server opens a short window: a marker sweeps
	a track (0 -> 1 -> 0, a triangle wave) and the player may tap once. Stopping the
	marker inside the sweet spot is a Perfect pour, inside the outer zone is Good,
	and missing or expiring is Poor.
--]]

---> types

export type PourTier = "Perfect" | "Good" | "Poor"

export type Config = {
	PERIOD_SECONDS: number,
	DURATION_SECONDS: number,
	ZONE_WIDTH: number,
	PERFECT_WIDTH: number,
	ZONE_CENTER_MIN: number,
	ZONE_CENTER_MAX: number,
	LATENCY_ALLOWANCE_SECONDS: number,
}

export type Window = {
	Id: number,
	StartedAt: number,
	ZoneCenter: number,
	ZoneWidth: number,
	PerfectWidth: number,
	Period: number,
	Duration: number,
}

-- What the client gets to draw the meter. Same numbers as the window, no clock.
export type View = {
	Id: number,
	ZoneCenter: number,
	ZoneWidth: number,
	PerfectWidth: number,
	Period: number,
	Duration: number,
}

---> public

local PourMeter = {}

-- Marker position in [0, 1] after `elapsed` seconds: 0 -> 1 in half a period, then back.
function PourMeter.Position(elapsed: number, period: number): number
	if period <= 0 or elapsed <= 0 then
		return 0
	end
	local phase = (elapsed % period) / period
	if phase < 0.5 then
		return phase * 2
	end
	return 2 - phase * 2
end

-- True when `position` is inside the zone (edges count).
function PourMeter.InZone(position: number, zoneCenter: number, zoneWidth: number): boolean
	return math.abs(position - zoneCenter) <= zoneWidth / 2
end

-- A new window starting at `now`. `roll` in [0, 1) places the zone between the
-- configured centres, so it never sits at the start where the marker begins.
function PourMeter.NewWindow(id: number, now: number, roll: number, config: Config): Window
	local center = config.ZONE_CENTER_MIN + math.clamp(roll, 0, 1) * (config.ZONE_CENTER_MAX - config.ZONE_CENTER_MIN)
	return {
		Id = id,
		StartedAt = now,
		ZoneCenter = center,
		ZoneWidth = config.ZONE_WIDTH,
		PerfectWidth = config.PERFECT_WIDTH,
		Period = config.PERIOD_SECONDS,
		Duration = config.DURATION_SECONDS,
	}
end

function PourMeter.ToView(window: Window): View
	return {
		Id = window.Id,
		ZoneCenter = window.ZoneCenter,
		ZoneWidth = window.ZoneWidth,
		PerfectWidth = window.PerfectWidth,
		Period = window.Period,
		Duration = window.Duration,
	}
end

-- The elapsed time the server grades: the client's claim, clamped to
-- [serverElapsed - allowance, serverElapsed]. A missing or invalid claim uses the
-- server's own time (the honest worst case: late by one ping).
function PourMeter.EffectiveElapsed(claimed: any, serverElapsed: number, allowance: number): number
	local low = math.max(0, serverElapsed - allowance)
	if typeof(claimed) ~= "number" or claimed ~= claimed or claimed == math.huge or claimed == -math.huge then
		return serverElapsed
	end
	return math.clamp(claimed, low, math.max(low, serverElapsed))
end

-- Grades one tap. Returns (PourTier, reason): reason is "Ok", "Miss", "Expired" or "Early".
function PourMeter.Resolve(window: Window, claimed: any, now: number, allowance: number): (PourTier, string)
	local serverElapsed = now - window.StartedAt
	if serverElapsed < 0 then
		return "Poor", "Early"
	end
	if serverElapsed > window.Duration + allowance then
		return "Poor", "Expired"
	end
	local elapsed = PourMeter.EffectiveElapsed(claimed, serverElapsed, allowance)
	if elapsed > window.Duration then
		return "Poor", "Expired"
	end
	local position = PourMeter.Position(elapsed, window.Period)
	local dist = math.abs(position - window.ZoneCenter)
	if dist <= window.PerfectWidth / 2 then
		return "Perfect", "Ok"
	elseif dist <= window.ZoneWidth / 2 then
		return "Good", "Ok"
	else
		return "Poor", "Miss"
	end
end

-- The drink's PerfectPours after one more perfect, never above `cap`.
function PourMeter.AddPerfect(current: any, cap: number): number
	local count = if typeof(current) == "number" and current == current then math.floor(current) else 0
	return math.clamp(count + 1, 0, math.max(0, cap))
end

-- The flat tip for a set of served tools' PerfectPours values.
-- If a tool has poor pours (or passed as 0), no tip.
function PourMeter.TipFor(drinks: { any }, tipPerPerfect: number, capPerDrink: number): number
	local total = 0
	for _, value in drinks do
		local perfectCount = 0
		local hasPoor = false
		if typeof(value) == "table" then
			if
				(typeof(value.Poor) == "number" and value.Poor > 0)
				or (typeof(value.PoorPours) == "number" and value.PoorPours > 0)
			then
				hasPoor = true
			else
				local count = value.Perfect or value.PerfectPours
				if typeof(count) == "number" and count == count and count > 0 then
					perfectCount = count
				end
			end
		elseif typeof(value) == "number" and value == value and value > 0 then
			perfectCount = value
		end

		if not hasPoor and perfectCount > 0 then
			total += math.min(math.floor(perfectCount), capPerDrink)
		end
	end
	return total * tipPerPerfect
end

return PourMeter
