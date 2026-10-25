--!strict
--[[
	Seats.luau (REVIVAL-001 BIG-B4)
	Pool manager for living cafe customer seating.
	Scans authored seats under workspace.Assets.NPC.Seats and coordinates
	seat reservations and budget enforcement for served NPCs.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeatingConfig = require(Shared.Configuration.SeatingConfig)

export type BudgetSpec = number | () -> number

export type SeatsPool = {
	TryClaim: (self: SeatsPool, npcId: string, originPos: Vector3, maxDist: number?) -> Seat?,
	Release: (self: SeatsPool, seat: Seat?, npcId: string?) -> (),
	Forget: (self: SeatsPool, npcId: string) -> (),
	BudgetUsed: (self: SeatsPool) -> number,
}

type SeatsPoolImpl = {
	_seats: { Seat },
	_budget: BudgetSpec,
	_claimed: { [string]: Seat },
	_bySeat: { [Seat]: string },
	_claimedCount: number,
} & SeatsPool

local SeatsPoolClass = {}
SeatsPoolClass.__index = SeatsPoolClass

function SeatsPoolClass.BudgetUsed(self: SeatsPoolImpl): number
	return self._claimedCount
end

function SeatsPoolClass.TryClaim(self: SeatsPoolImpl, npcId: string, originPos: Vector3, maxDist: number?): Seat?
	local budgetLimit = if typeof(self._budget) == "function" then self._budget() else self._budget
	if self._claimedCount >= budgetLimit then
		return nil
	end
	if self._claimed[npcId] ~= nil then
		return nil
	end

	local maxDistance = maxDist or SeatingConfig.SEAT_MAX_DISTANCE_STUDS
	local bestSeat: Seat? = nil
	local bestDist = math.huge

	for _, seat in self._seats do
		if not seat:IsA("Seat") or seat:IsA("VehicleSeat") then
			continue
		end
		if seat.Disabled then
			continue
		end
		if seat.Occupant ~= nil then
			continue
		end
		if seat:GetAttribute("NpcReservedBy") ~= nil then
			continue
		end
		if self._bySeat[seat] ~= nil then
			continue
		end

		local dist = (seat.Position - originPos).Magnitude
		if dist <= maxDistance and dist < bestDist then
			bestDist = dist
			bestSeat = seat
		end
	end

	if bestSeat ~= nil then
		bestSeat:SetAttribute("NpcReservedBy", npcId)
		self._claimed[npcId] = bestSeat
		self._bySeat[bestSeat] = npcId
		self._claimedCount += 1
		return bestSeat
	end

	return nil
end

function SeatsPoolClass.Release(self: SeatsPoolImpl, seat: Seat?, npcId: string?)
	if npcId ~= nil then
		local held = self._claimed[npcId]
		if held ~= nil and (seat == nil or seat == held) then
			held:SetAttribute("NpcReservedBy", nil)
			self._claimed[npcId] = nil
			self._bySeat[held] = nil
			self._claimedCount = math.max(0, self._claimedCount - 1)
		end
	end

	if seat ~= nil then
		local holder = self._bySeat[seat]
		if holder ~= nil then
			self._claimed[holder] = nil
			self._bySeat[seat] = nil
			self._claimedCount = math.max(0, self._claimedCount - 1)
		end
		seat:SetAttribute("NpcReservedBy", nil)
	end
end

function SeatsPoolClass.Forget(self: SeatsPoolImpl, npcId: string)
	local seat = self._claimed[npcId]
	if seat ~= nil then
		self:Release(seat, npcId)
	end

	for _, s in self._seats do
		if s:GetAttribute("NpcReservedBy") == npcId then
			s:SetAttribute("NpcReservedBy", nil)
			if self._bySeat[s] == npcId then
				self._bySeat[s] = nil
			end
		end
	end
end

local Seats = {}

function Seats.Resolve(): { Seat }
	local seats: { Seat } = {}
	local assets = workspace:FindFirstChild("Assets")
	local seatsFolder = nil
	if assets ~= nil then
		local npc = assets:FindFirstChild("NPC")
		seatsFolder = if npc ~= nil then npc:FindFirstChild("Seats") else nil
		if seatsFolder == nil then
			seatsFolder = assets:FindFirstChild("Seating")
		end
	end

	if seatsFolder ~= nil then
		for _, descendant in seatsFolder:GetDescendants() do
			if descendant:IsA("Seat") and not descendant:IsA("VehicleSeat") then
				table.insert(seats, descendant :: Seat)
			end
		end
	end

	return seats
end

function Seats.new(seats: { Seat }?, budget: BudgetSpec?): SeatsPool
	local self: SeatsPoolImpl = {
		_seats = seats or Seats.Resolve(),
		_budget = budget or SeatingConfig.SEATED_BUDGET,
		_claimed = {},
		_bySeat = {},
		_claimedCount = 0,
	} :: any
	return setmetatable(self, SeatsPoolClass) :: any
end

return Seats
