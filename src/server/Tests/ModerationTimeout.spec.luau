-- selene: allow(undefined_variable)
--[[
	ModerationTimeout.spec.luau
	TestEZ tests for the moderation timeout record (timeout command): expiry
	checks and the player-facing denial line. Both are pure, so these tests
	need no Instances and no authored place content.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")

	local ModerationService = require(ServerScriptService.Server.Modules.ModerationService)

	local function record(expiresAt: number): { [string]: any }
		return {
			Reason = "Griefing the line",
			IssuedBy = "Mod",
			IssuedAt = 1000,
			ExpiresAt = expiresAt,
		}
	end

	describe("CheckTimeout", function()
		it("should reject a missing record", function()
			local active, remaining = ModerationService.CheckTimeout(nil, 1500)
			expect(active).to.equal(false)
			expect(remaining).to.equal(0)
		end)

		it("should reject a record without ExpiresAt", function()
			local active, _ = ModerationService.CheckTimeout({ Reason = "x" }, 1500)
			expect(active).to.equal(false)
		end)

		it("should reject an expired record", function()
			local active, remaining = ModerationService.CheckTimeout(record(1400), 1500)
			expect(active).to.equal(false)
			expect(remaining).to.equal(0)
		end)

		it("should reject a record expiring exactly now", function()
			local active, _ = ModerationService.CheckTimeout(record(1500), 1500)
			expect(active).to.equal(false)
		end)

		it("should accept an active record with remaining time", function()
			local active, remaining = ModerationService.CheckTimeout(record(1500 + 300), 1500)
			expect(active).to.equal(true)
			expect(remaining).to.equal(300)
		end)
	end)

	describe("TimeoutMessage", function()
		it("should name the remaining minutes and reason", function()
			local message = ModerationService.TimeoutMessage(record(2000), 300)
			expect(string.find(message, "5 more minute", 1, true) ~= nil).to.equal(true)
			expect(string.find(message, "Griefing the line", 1, true) ~= nil).to.equal(true)
		end)

		it("should round partial minutes up", function()
			local message = ModerationService.TimeoutMessage(record(2000), 61)
			expect(string.find(message, "2 more minute", 1, true) ~= nil).to.equal(true)
		end)

		it("should fall back to the default reason", function()
			local message = ModerationService.TimeoutMessage({ ExpiresAt = 2000 }, 60)
			expect(string.find(message, "Disrupting other players.", 1, true) ~= nil).to.equal(true)
		end)
	end)
end
