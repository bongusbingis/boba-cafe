-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
    ShiftService.spec.luau
    TestEZ tests for ShiftService (clocked-in state).

    Uses fake player tables with an in-memory attribute store, so no real
    players and no authored place content are needed.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local service = require(ServerScriptService.Server.Modules.ShiftService) :: any

	-- Fake player with the fields and attribute methods ShiftService uses
	local function makePlayer(userId: number): any
		local attributes = {}
		local player = {
			UserId = userId,
			Name = "Player_" .. userId,
		}
		function player:GetAttribute(name: string): any
			return attributes[name]
		end
		function player:SetAttribute(name: string, value: any)
			attributes[name] = value
		end
		return player
	end

	local originalShiftEnded = service.Client.ShiftEnded
	local originalPaycheck = service.Client.Paycheck
	local firedPaychecks = {}

	beforeEach(function()
		service._toggleDebounces = {}
		service.Client.Server = service
		service.Client.ShiftEnded = {
			Fire = function(_self, _player, _summary) end,
		}
		firedPaychecks = {}
		service.Client.Paycheck = {
			Fire = function(_self, _player, paycheck)
				table.insert(firedPaychecks, { Player = _player, Paycheck = paycheck })
			end,
		}
	end)

	afterEach(function()
		service._toggleDebounces = {}
	end)

	afterAll(function()
		service.Client.ShiftEnded = originalShiftEnded
		service.Client.Paycheck = originalPaycheck
	end)

	describe("IsClockedIn / SetClockedIn", function()
		it("should report clocked out when the attribute is unset", function()
			local player = makePlayer(1001)
			expect(service:IsClockedIn(player)).to.equal(false)
		end)

		it("should store the state on the ClockedIn attribute", function()
			local player = makePlayer(1002)
			service:SetClockedIn(player, true)
			expect(player:GetAttribute("ClockedIn")).to.equal(true)
			expect(service:IsClockedIn(player)).to.equal(true)

			service:SetClockedIn(player, false)
			expect(player:GetAttribute("ClockedIn")).to.equal(false)
			expect(service:IsClockedIn(player)).to.equal(false)
		end)

		it("should fire ClockedInChanged only when the value changes", function()
			local player = makePlayer(1003)
			local fired = {}
			local connection = service.ClockedInChanged:Connect(function(changedPlayer, clockedIn)
				if changedPlayer == player then
					table.insert(fired, clockedIn)
				end
			end)

			service:SetClockedIn(player, true)
			service:SetClockedIn(player, true) -- unchanged, no fire
			service:SetClockedIn(player, false)
			connection:Disconnect()

			expect(#fired).to.equal(2)
			expect(fired[1]).to.equal(true)
			expect(fired[2]).to.equal(false)
		end)

		it("should keep a loaded shift across clock out and back in", function()
			local player = makePlayer(1006)
			player:SetAttribute("ClockedIn", false)
			local state = { Resolved = 2, Target = 5, Loaded = true }
			service._states[player] = state
			player:SetAttribute("ClockedIn", true) -- so the next call is a real change
			service:SetClockedIn(player, false)
			expect(service._states[player]).to.equal(nil)
			service:SetClockedIn(player, true)
			expect(service._states[player]).to.equal(state)
			expect(player:GetAttribute("ShiftCount")).to.equal(2)
			service._states[player] = nil
			service._paused[player] = nil
		end)
	end)

	describe("PlayerAdded", function()
		it("should clock new players in by default", function()
			local player = makePlayer(1004)
			service:PlayerAdded(player)
			expect(service:IsClockedIn(player)).to.equal(true)
		end)

		it("should keep a value that is already set", function()
			local player = makePlayer(1005)
			player:SetAttribute("ClockedIn", false)
			service:PlayerAdded(player)
			expect(service:IsClockedIn(player)).to.equal(false)
		end)
	end)

	describe("Client.SetClockedIn", function()
		it("should reject non-boolean values", function()
			local player = makePlayer(1006)
			local result = service.Client:SetClockedIn(player, "yes")
			expect(result.Success).to.equal(false)
			expect(player:GetAttribute("ClockedIn")).to.equal(nil)
			expect(service._toggleDebounces[player.UserId]).to.equal(nil)
		end)

		it("should apply a boolean request", function()
			local player = makePlayer(1007)
			local result = service.Client:SetClockedIn(player, false)
			expect(result.Success).to.equal(true)
			expect(service:IsClockedIn(player)).to.equal(false)
		end)

		it("should rate-limit repeated requests per player", function()
			local player = makePlayer(1008)
			service.Client:SetClockedIn(player, true)
			local result = service.Client:SetClockedIn(player, false)
			expect(result.Success).to.equal(false)
			expect(service:IsClockedIn(player)).to.equal(true)
		end)

		it("should not rate-limit a different player", function()
			local first = makePlayer(1009)
			local second = makePlayer(1010)
			service.Client:SetClockedIn(first, true)
			local result = service.Client:SetClockedIn(second, true)
			expect(result.Success).to.equal(true)
		end)

		it("should clear the rate limit on PlayerRemoving", function()
			local player = makePlayer(1011)
			service.Client:SetClockedIn(player, true)
			service:PlayerRemoving(player)
			expect(service._toggleDebounces[player.UserId]).to.equal(nil)
		end)
	end)

	describe("StarsFor", function()
		it("gives 3 stars for no walkouts and 80% Perfect or better", function()
			expect(service.StarsFor(10, 10, 0)).to.equal(3)
			expect(service.StarsFor(10, 8, 0)).to.equal(3)
			expect(service.StarsFor(5, 4, 0)).to.equal(3)
		end)

		it("gives 2 stars for at most 1 walkout and 50% Perfect or better", function()
			expect(service.StarsFor(10, 7, 0)).to.equal(2)
			expect(service.StarsFor(10, 10, 1)).to.equal(2)
			expect(service.StarsFor(10, 5, 1)).to.equal(2)
		end)

		it("gives 1 star otherwise", function()
			expect(service.StarsFor(10, 4, 0)).to.equal(1)
			expect(service.StarsFor(10, 10, 2)).to.equal(1)
			expect(service.StarsFor(0, 0, 0)).to.equal(1)
		end)
	end)

	describe("Shift star bonus", function()
		it("pays 5 / 10 / 15 BobaBucks for 1 / 2 / 3 stars", function()
			local ShiftConfig = require(ReplicatedStorage.Shared.Configuration.ShiftConfig)
			expect(ShiftConfig.SHIFT_BONUS_PER_STAR * 1).to.equal(5)
			expect(ShiftConfig.SHIFT_BONUS_PER_STAR * 2).to.equal(10)
			expect(ShiftConfig.SHIFT_BONUS_PER_STAR * 3).to.equal(15)
		end)

		it("reports Bonus == 15 in the summary of a 3-star shift", function()
			local player = makePlayer(9001)
			local state = {
				Resolved = 10,
				Target = 10,
				Served = 10,
				Walkouts = 0,
				Perfects = 10,
				Pay = 0,
				Tips = 0,
				BestCombo = 0,
				Completed = 1,
				Loaded = true,
			}
			local captured = nil
			local connection = service.ShiftEnding:Connect(function(_, summary)
				captured = summary
			end)
			service._states[player] = state
			service:_endShift(player, state)
			connection:Disconnect()
			service._states[player] = nil

			expect(captured).to.be.ok()
			expect(captured.Stars).to.equal(3)
			expect(captured.Bonus).to.equal(15)
		end)
	end)
	describe("Tips line", function()
		it("sums result.Tip and AddTip floors, and resets each shift", function()
			local player = makePlayer(9100)
			local state = {
				Resolved = 0,
				Target = 10,
				Served = 0,
				Walkouts = 0,
				Perfects = 0,
				Pay = 0,
				Tips = 0,
				BestCombo = 0,
				Completed = 1,
				Loaded = true,
			}
			service._states[player] = state
			service:RecordCustomer(
				player,
				{ Kind = "Served", Grade = "Close", Pay = 20, Fast = false, Combo = 1, Tip = 3 }
			)
			service:AddTip(player, 2.9)
			service:AddTip(player, 0)
			expect(state.Tips).to.equal(5)
			expect(state.Pay).to.equal(22)

			local captured = nil
			local connection = service.ShiftEnding:Connect(function(_, summary)
				captured = summary
			end)
			service:_endShift(player, state)
			connection:Disconnect()
			expect(captured.Tips).to.equal(5)
			expect(captured.Pay).to.equal(17)
			expect(service._states[player].Tips).to.equal(0)
			service._states[player] = nil
		end)
	end)

	describe("Paycheck receipt", function()
		it("fires one paycheck with the shift pay lines and total", function()
			local player = makePlayer(9201)
			local state = {
				Resolved = 10,
				Target = 10,
				Served = 9,
				Walkouts = 1,
				Perfects = 9,
				Pay = 17,
				Tips = 5,
				BestCombo = 4,
				Completed = 2,
				Loaded = true,
			}
			service._states[player] = state
			service:_endShift(player, state)
			service._states[player] = nil

			expect(#firedPaychecks).to.equal(1)
			local fired = firedPaychecks[1]
			expect(fired.Player).to.equal(player)
			local paycheck = fired.Paycheck
			expect(paycheck.Pay).to.equal(17)
			expect(paycheck.Tips).to.equal(5)
			expect(paycheck.Total).to.equal(paycheck.Pay + paycheck.Tips + paycheck.Bonus)
			expect(paycheck.Served).to.equal(9)
			expect(paycheck.Walkouts).to.equal(1)
			expect(paycheck.Shift).to.equal(3)
			expect(paycheck.First).to.equal(false)
		end)
	end)
	describe("personal bests and capsule price", function()
		local function endWith(prevCombo: number?, prevPay: number?, combo: number, pay: number)
			local player = makePlayer(9300 + combo)
			local state = {
				Resolved = 5,
				Target = 5,
				Served = 5,
				Walkouts = 0,
				Perfects = 5,
				Pay = pay,
				Tips = 0,
				BestCombo = combo,
				Completed = 1,
				Loaded = true,
				PrevBestCombo = prevCombo,
				PrevBestShiftPay = prevPay,
			}
			service._states[player] = state
			local captured = nil
			local connection = service.ShiftEnding:Connect(function(_, summary)
				captured = summary
			end)
			service:_endShift(player, state)
			connection:Disconnect()
			service._states[player] = nil
			return captured
		end

		it("flags a new best only above a stored best", function()
			local summary = endWith(3, 40, 5, 60)
			expect(summary.NewBestCombo).to.equal(true)
			expect(summary.NewBestShiftPay).to.equal(true)
		end)

		it("never flags a first-ever shift or an unknown best", function()
			local first = endWith(0, 0, 5, 60)
			expect(first.NewBestCombo).to.equal(false)
			expect(first.NewBestShiftPay).to.equal(false)
			local unknown = endWith(nil, nil, 5, 60)
			expect(unknown.NewBestCombo).to.equal(false)
			expect(unknown.NewBestShiftPay).to.equal(false)
		end)

		it("reads the cheapest capsule price from definitions", function()
			local price = service.CheapestCapsulePrice()
			expect(typeof(price)).to.equal("number")
			expect(price > 0).to.equal(true)
		end)
	end)

	describe("Shift streak bonus", function()
		local function endShiftOnce(player: any, completed: number, served: number?)
			local servedCount = if served == nil then 10 else served
			local state = {
				Resolved = 10,
				Target = 10,
				Served = servedCount,
				Walkouts = 10 - servedCount,
				Perfects = servedCount,
				Pay = 0,
				Tips = 0,
				BestCombo = 0,
				Completed = completed,
				Loaded = true,
			}
			service._states[player] = state
			local captured = nil
			local connection = service.ShiftEnding:Connect(function(_, summary)
				captured = summary
			end)
			service:_endShift(player, state)
			connection:Disconnect()
			service._states[player] = nil
			return captured
		end

		it("grants the streak bonus on every 3rd consecutive shift end", function()
			local player = makePlayer(9401)
			local first = endShiftOnce(player, 1)
			local second = endShiftOnce(player, 2)
			local third = endShiftOnce(player, 3)
			expect(first.ShiftStreak).to.equal(1)
			expect(first.StreakBonus).to.equal(0)
			expect(second.ShiftStreak).to.equal(2)
			expect(second.StreakBonus).to.equal(0)
			expect(third.ShiftStreak).to.equal(3)
			expect(third.StreakBonus).to.equal(30)
			local fourth = endShiftOnce(player, 4)
			expect(fourth.ShiftStreak).to.equal(4)
			expect(fourth.StreakBonus).to.equal(0)
			service:PlayerRemoving(player)
		end)

		it("an all-walkout shift breaks the streak and pays no streak bonus (TAKEOVER-REVIEW-FIX P3-9)", function()
			local player = makePlayer(9403)
			endShiftOnce(player, 1)
			endShiftOnce(player, 2)
			local empty = endShiftOnce(player, 3, 0)
			expect(empty.ShiftStreak).to.equal(0)
			expect(empty.StreakBonus).to.equal(0)
			local after = endShiftOnce(player, 4)
			expect(after.ShiftStreak).to.equal(1)
			service:PlayerRemoving(player)
		end)

		it("clears the streak on PlayerRemoving", function()
			local player = makePlayer(9402)
			endShiftOnce(player, 1)
			service:PlayerRemoving(player)
			expect(service._streaks[player]).to.equal(nil)
		end)
	end)
end
