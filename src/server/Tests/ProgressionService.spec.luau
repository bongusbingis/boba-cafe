-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	ProgressionService.spec.luau
	TestEZ tests for the shift-card XP prediction and the level-up toast text
	(REVIVAL-001 REVIEW-FIX P2-1 / E-O1). Fake players only; AddXp is stubbed to
	the synchronous path a loaded profile takes.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Progression = require(ReplicatedStorage.Shared.Configuration.Progression)
	local ShiftConfig = require(ReplicatedStorage.Shared.Configuration.ShiftConfig)
	local CustomerConfig = require(ReplicatedStorage.Shared.Configuration.CustomerConfig)
	local service = require(ServerScriptService.Server.Modules.ProgressionService) :: any

	local function makePlayer(level: number): any
		local attributes = { Level = level }
		local player = { UserId = -9100, Name = "ProgressionSpec" }
		function player:GetAttribute(name: string): any
			return attributes[name]
		end
		function player:SetAttribute(name: string, value: any)
			attributes[name] = value
		end
		return player
	end

	describe("Predict", function()
		it("carries XP over level boundaries", function()
			local after, into = service.Predict(1, 80, 10)
			expect(after).to.equal(2)
			expect(into).to.equal(80 + 10 - Progression.XpToNext(1))
		end)

		it("stays on the level below the threshold", function()
			local after, into = service.Predict(2, 0, 5)
			expect(after).to.equal(2)
			expect(into).to.equal(5)
		end)
	end)

	describe("_applyShiftXp", function()
		local originalAddXp
		local player

		beforeEach(function()
			originalAddXp = service.AddXp
			player = makePlayer(2)
		end)

		afterEach(function()
			service.AddXp = originalAddXp
			service._state[player] = nil
			service._shiftXp[player] = nil
		end)

		-- Mirrors AddXp on a loaded profile: the cache already includes the XP when it returns.
		local function stubSyncAddXp()
			service.AddXp = function(self, p, amount)
				local state = self._state[p]
				state.XP += amount
				while state.XP >= Progression.XpToNext(state.Level) do
					state.XP -= Progression.XpToNext(state.Level)
					state.Level += 1
				end
				return amount
			end
		end

		it("does not count the shift XP twice when AddXp applies synchronously", function()
			stubSyncAddXp()
			local shiftXp = ShiftConfig.SHIFT_XP + ShiftConfig.SHIFT_XP_PER_STAR * 1
			local start = Progression.XpToNext(2) - shiftXp - 1 -- one short of level 3 after the grant
			service._state[player] = { Level = 2, XP = start }
			local summary = { Stars = 1 }
			service:_applyShiftXp(player, summary)
			expect(summary.LevelBefore).to.equal(2)
			expect(summary.LevelAfter).to.equal(2)
			expect(summary.XpIntoLevel).to.equal(start + shiftXp)
			expect(summary.XpForLevel).to.equal(Progression.XpToNext(2))
			-- The card matches the cache the LevelBar reads.
			expect(service._state[player].Level).to.equal(summary.LevelAfter)
			expect(service._state[player].XP).to.equal(summary.XpIntoLevel)
		end)

		it("reports a real level-up from the shift XP", function()
			stubSyncAddXp()
			local shiftXp = ShiftConfig.SHIFT_XP
			service._state[player] = { Level = 2, XP = Progression.XpToNext(2) - 1 }
			local summary = { Stars = 0 }
			service:_applyShiftXp(player, summary)
			expect(summary.LevelAfter).to.equal(3)
			expect(summary.XpIntoLevel).to.equal(shiftXp - 1)
		end)

		it("adds serve XP to the card total", function()
			stubSyncAddXp()
			service._state[player] = { Level = 2, XP = 0 }
			service._shiftXp[player] = 12
			local summary = { Stars = 0 }
			service:_applyShiftXp(player, summary)
			expect(summary.Xp).to.equal(12 + ShiftConfig.SHIFT_XP)
			expect(service._shiftXp[player]).to.equal(0)
		end)

		it("reads the cache without adding again when there was no cache before AddXp", function()
			service.AddXp = function(self, p, amount)
				self._state[p] = { Level = 2, XP = 7 + amount }
				return amount
			end
			local summary = { Stars = 0 }
			service:_applyShiftXp(player, summary)
			expect(summary.LevelAfter).to.equal(2)
			expect(summary.XpIntoLevel).to.equal(7 + ShiftConfig.SHIFT_XP)
		end)
	end)

	describe("UnlocksAt", function()
		local function has(level: number, needle: string): boolean
			for _, line in service.UnlocksAt(level) do
				if string.find(line, needle, 1, true) then
					return true
				end
			end
			return false
		end

		it("lists the level 5 bundle", function()
			expect(has(5, "New title: Barista")).to.equal(true)
			expect(has(5, "2 order tickets")).to.equal(true)
			expect(has(5, "Orders with 2 items")).to.equal(true)
			expect(has(5, "New nametag: Crimson")).to.equal(true)
		end)

		it("lists new drinks at their level", function()
			expect(has(2, "Taro Boba")).to.equal(true)
			expect(has(2, "Strawberry Boba")).to.equal(true)
			expect(has(7, "Espresso")).to.equal(true)
		end)

		it("lists variant customers at their level", function()
			expect(has(6, "VIP customers")).to.equal(true)
			expect(has(10, "Karen customers")).to.equal(true)
		end)
	end)

	describe("LevelUpText", function()
		it("names every drink that opens at its level", function()
			for _, entry in CustomerConfig.ORDER_POOL do
				if entry.MinLevel > 1 then
					local text = service.LevelUpText(entry.MinLevel)
					expect(string.find(text, entry.Label, 1, true)).to.be.ok()
				end
			end
		end)

		it("keeps the nametag reward", function()
			for level, reward in Progression.COSMETIC_REWARDS do
				local text = service.LevelUpText(level)
				expect(string.find(text, `New nametag: {reward.Name}`, 1, true)).to.be.ok()
			end
		end)

		it("starts with the level line", function()
			expect(string.find(service.LevelUpText(4), "^Level up! You are now level 4")).to.be.ok()
		end)
	end)
end
