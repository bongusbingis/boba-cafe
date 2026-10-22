--!strict
--[[
	CafeEvent
	Client view of the server-wide Rush Hour and Boba Party (EVENT-FX). CafeRatingService
	publishes RushHour, BobaParty, BobaPartyBuyer and RushEndsAt on workspace; this reads them
	as one state. Observe coalesces a burst of attribute changes into one callback: the server
	sets RushHour and BobaParty in the same frame, and the client applies them one at a time.
]]

export type Mode = "Rush" | "Party"
export type Intro = "Rush" | "Party" | "Extended" | "RushExtended"

export type State = {
	Mode: Mode?,
	Buyer: string?,
	EndsAt: number?,
}

local ATTRIBUTES = { "RushHour", "BobaParty", "BobaPartyBuyer", "RushHourBuyer", "RushEndsAt" }
-- An end time that jumps by more than this while a party runs is an extension.
local EXTEND_THRESHOLD_SECONDS = 30

local CafeEvent = {}

function CafeEvent.read(): State
	local party = workspace:GetAttribute("BobaParty") == true
	local rush = workspace:GetAttribute("RushHour") == true
	local buyer = workspace:GetAttribute(if party then "BobaPartyBuyer" else "RushHourBuyer")
	local endsAt = workspace:GetAttribute("RushEndsAt")
	return {
		Mode = if party then "Party" elseif rush then "Rush" else nil,
		Buyer = if (party or rush) and typeof(buyer) == "string" and buyer ~= "" then buyer else nil,
		EndsAt = if typeof(endsAt) == "number" then endsAt else nil,
	}
end

--- Pure: which intro (if any) the change from prev to nextState should play.
function CafeEvent.introFor(prev: State, nextState: State): Intro?
	if nextState.Mode == nil or nextState.Mode ~= prev.Mode then
		return nextState.Mode
	end
	if prev.EndsAt ~= nil and nextState.EndsAt ~= nil and nextState.EndsAt - prev.EndsAt > EXTEND_THRESHOLD_SECONDS then
		return if nextState.Mode == "Party" then "Extended" else "RushExtended"
	end
	return nil
end

--- Calls callback(state) once per settled change. Returns a disconnect function.
function CafeEvent.observe(callback: (State) -> ()): () -> ()
	local pending = false
	local alive = true
	local function schedule()
		if pending then
			return
		end
		pending = true
		task.defer(function()
			pending = false
			if alive then
				callback(CafeEvent.read())
			end
		end)
	end

	local conns = {}
	for _, name in ATTRIBUTES do
		table.insert(conns, workspace:GetAttributeChangedSignal(name):Connect(schedule))
	end
	return function()
		alive = false
		for _, conn in conns do
			conn:Disconnect()
		end
	end
end

return CafeEvent
