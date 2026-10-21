-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	PourMeter.spec.luau
	TestEZ tests for the station skill-moment pure logic (REVIVAL-001 BIG-B7).
	No Roblox instances are touched, so these run anywhere the shared module
	loads. Grading cases use the shipped tuning shape (period 1.6, duration
	3.2, zone width 0.24, perfect width 0.10, allowance 0.3) with explicit zone centres.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local PourMeter = require(ReplicatedStorage.Shared.Kitchen.PourMeter)

	local function config()
		return {
			PERIOD_SECONDS = 1.6,
			DURATION_SECONDS = 3.2,
			ZONE_WIDTH = 0.24,
			PERFECT_WIDTH = 0.10,
			ZONE_CENTER_MIN = 0.45,
			ZONE_CENTER_MAX = 0.8,
			LATENCY_ALLOWANCE_SECONDS = 0.3,
		}
	end

	local function windowAt(center: number, startedAt: number?): any
		local window = PourMeter.NewWindow(7, startedAt or 100, (center - 0.45) / (0.8 - 0.45), config())
		window.ZoneCenter = center -- pin the centre so cases read exactly
		return window
	end

	describe("Position", function()
		it("starts at 0 and sweeps 0 -> 1 -> 0 over one period", function()
			expect(PourMeter.Position(0, 1.6)).to.equal(0)
			expect(PourMeter.Position(0.4, 1.6)).to.equal(0.5)
			expect(PourMeter.Position(0.8, 1.6)).to.equal(1)
			expect(math.abs(PourMeter.Position(1.2, 1.6) - 0.5) < 1e-9).to.equal(true)
		end)

		it("wraps into a second sweep", function()
			expect(PourMeter.Position(1.6, 1.6)).to.equal(0)
			-- Binary floats rarely land exactly on 0.5 mid-sweep; compare closely.
			expect(math.abs(PourMeter.Position(2.0, 1.6) - 0.5) < 1e-9).to.equal(true)
		end)

		it("treats non-positive time or period as the start", function()
			expect(PourMeter.Position(-1, 1.6)).to.equal(0)
			expect(PourMeter.Position(1, 0)).to.equal(0)
		end)
	end)

	describe("InZone", function()
		it("counts edges as inside", function()
			expect(PourMeter.InZone(0.5, 0.5, 0.24)).to.equal(true)
			expect(PourMeter.InZone(0.38, 0.5, 0.24)).to.equal(true)
			expect(PourMeter.InZone(0.62, 0.5, 0.24)).to.equal(true)
		end)

		it("rejects positions outside the zone", function()
			expect(PourMeter.InZone(0.37, 0.5, 0.24)).to.equal(false)
			expect(PourMeter.InZone(0.63, 0.5, 0.24)).to.equal(false)
		end)
	end)

	describe("NewWindow", function()
		it("rolls the zone centre across the configured band", function()
			local low = PourMeter.NewWindow(1, 0, 0, config())
			local high = PourMeter.NewWindow(2, 0, 1, config())
			expect(low.ZoneCenter).to.equal(0.45)
			expect(high.ZoneCenter).to.equal(0.8)
			expect(low.PerfectWidth).to.equal(0.10)
		end)

		it("clamps an out-of-range roll instead of erroring", function()
			expect(PourMeter.NewWindow(1, 0, -5, config()).ZoneCenter).to.equal(0.45)
			expect(PourMeter.NewWindow(2, 0, 5, config()).ZoneCenter).to.equal(0.8)
		end)
	end)

	describe("EffectiveElapsed", function()
		it("accepts a claim inside the latency window", function()
			expect(PourMeter.EffectiveElapsed(1.0, 1.2, 0.3)).to.equal(1.0)
		end)

		it("clamps a stale claim up to the latency floor", function()
			local elapsed = PourMeter.EffectiveElapsed(0.1, 1.2, 0.3)
			expect(math.abs(elapsed - 0.9) < 0.0001).to.equal(true)
		end)

		it("never grades later than the server clock", function()
			expect(PourMeter.EffectiveElapsed(9.9, 1.2, 0.3)).to.equal(1.2)
		end)

		it("falls back to the server time for a missing or bad claim", function()
			expect(PourMeter.EffectiveElapsed(nil, 1.2, 0.3)).to.equal(1.2)
			expect(PourMeter.EffectiveElapsed(0 / 0, 1.2, 0.3)).to.equal(1.2)
			expect(PourMeter.EffectiveElapsed(math.huge, 1.2, 0.3)).to.equal(1.2)
			expect(PourMeter.EffectiveElapsed("soon", 1.2, 0.3)).to.equal(1.2)
		end)
	end)

	describe("Resolve", function()
		it("grades a bullseye tap as perfect", function()
			-- Period 1.6: the marker hits 0.62 at elapsed 0.496 and 1.104.
			local window = windowAt(0.62)
			local tier, reason = PourMeter.Resolve(window, 0.496, 100.496, 0.3)
			expect(reason).to.equal("Ok")
			expect(tier).to.equal("Perfect")
		end)

		it("grades a tap in outer zone as good", function()
			-- Center 0.62, perfect width 0.10, outer width 0.24.
			-- Elapsed 0.56 puts the marker at 0.70 (distance 0.08: inside 0.12 outer, outside 0.05 inner).
			local window = windowAt(0.62)
			local tier, reason = PourMeter.Resolve(window, 0.56, 100.56, 0.3)
			expect(reason).to.equal("Ok")
			expect(tier).to.equal("Good")
		end)

		it("grades a tap outside outer zone as poor miss", function()
			-- Elapsed 0.1 puts the marker at 0.125, far from a 0.62 centre.
			local window = windowAt(0.62)
			local tier, reason = PourMeter.Resolve(window, 0.1, 100.1, 0.3)
			expect(reason).to.equal("Miss")
			expect(tier).to.equal("Poor")
		end)

		it("credits a claim within one ping of the zone", function()
			-- The client watched 0.496 (a perfect) but the server is 0.2 ahead.
			local window = windowAt(0.62)
			local tier, _ = PourMeter.Resolve(window, 0.496, 100.696, 0.3)
			expect(tier).to.equal("Perfect")
		end)

		it("expires a tap past the window plus allowance as poor expired", function()
			local window = windowAt(0.62)
			local tier, reason = PourMeter.Resolve(window, 3.1, 103.6, 0.3)
			expect(reason).to.equal("Expired")
			expect(tier).to.equal("Poor")
		end)

		it("rejects a tap from before the window opened as poor early", function()
			local window = windowAt(0.62, 100)
			local tier, reason = PourMeter.Resolve(window, 0, 99.5, 0.3)
			expect(reason).to.equal("Early")
			expect(tier).to.equal("Poor")
		end)
	end)

	describe("AddPerfect", function()
		it("bumps the count and caps it", function()
			expect(PourMeter.AddPerfect(nil, 2)).to.equal(1)
			expect(PourMeter.AddPerfect(1, 2)).to.equal(2)
			expect(PourMeter.AddPerfect(2, 2)).to.equal(2)
			expect(PourMeter.AddPerfect(9, 2)).to.equal(2)
		end)

		it("treats a bad count as zero", function()
			expect(PourMeter.AddPerfect("many", 2)).to.equal(1)
			expect(PourMeter.AddPerfect(0 / 0, 2)).to.equal(1)
		end)
	end)

	describe("TipFor", function()
		it("pays one tip per perfect, capped per drink", function()
			expect(PourMeter.TipFor({ 1, 2 }, 1, 2)).to.equal(3)
			expect(PourMeter.TipFor({ 9 }, 1, 2)).to.equal(2)
		end)

		it("ignores missing and non-positive counts", function()
			expect(PourMeter.TipFor({ nil, 0, -1 }, 1, 2)).to.equal(0)
			expect(PourMeter.TipFor({}, 1, 2)).to.equal(0)
		end)

		it("pays nothing for a drink with poor pours", function()
			expect(PourMeter.TipFor({ { PerfectPours = 2, PoorPours = 1 } }, 1, 2)).to.equal(0)
			expect(PourMeter.TipFor({ { Perfect = 2, Poor = 1 } }, 1, 2)).to.equal(0)
		end)

		it("skips only the drinks with poor pours when multiple drinks are served", function()
			expect(PourMeter.TipFor({
				{ PerfectPours = 2, PoorPours = 0 },
				{ PerfectPours = 2, PoorPours = 1 },
			}, 1, 2)).to.equal(2)
		end)
	end)
end
