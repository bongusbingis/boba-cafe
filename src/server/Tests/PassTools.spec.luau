-- selene: allow(undefined_variable)
--[[
	PassTools.spec.luau
	TestEZ tests for the pass-tool config (emotes, perks) and the Mop Whack target pick.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local PassCatalog = require(ReplicatedStorage.Shared.Configuration.PassCatalog)
	local PassTools = require(ReplicatedStorage.Shared.Configuration.PassTools)
	local WhackTarget = require(ReplicatedStorage.Shared.Utility.WhackTarget)

	describe("PassTools perks", function()
		it("should name perks that PassCatalog grants", function()
			local found = {}
			for _, entry in PassCatalog do
				for _, perk in entry.Perks do
					found[perk] = true
				end
			end
			expect(found[PassTools.MopWhackPerk]).to.equal(true)
			expect(found[PassTools.FlyingMopPerk]).to.equal(true)
			expect(found[PassTools.EmotePackPerk]).to.equal(true)
		end)
	end)

	describe("PassTools.Emotes", function()
		it("should fit the 8 emote menu slots with unique names", function()
			expect(#PassTools.Emotes <= 8).to.equal(true)
			local seen = {}
			for _, emote in PassTools.Emotes do
				expect(seen[emote.Name]).to.equal(nil)
				seen[emote.Name] = true
				expect(typeof(emote.AnimationId)).to.equal("number")
				expect(emote.AnimationId > 0).to.equal(true)
			end
		end)
	end)

	describe("WhackTarget.Pick", function()
		local origin = Vector3.new(0, 0, 0)
		local look = Vector3.new(0, 0, -1)

		it("should pick a target in front within range", function()
			local key = WhackTarget.Pick(origin, look, { { Key = "a", Position = Vector3.new(0, 0, -5) } }, 10, 0.25)
			expect(key).to.equal("a")
		end)

		it("should ignore targets behind or out of range", function()
			local candidates = {
				{ Key = "behind", Position = Vector3.new(0, 0, 4) },
				{ Key = "far", Position = Vector3.new(0, 0, -30) },
			}
			expect(WhackTarget.Pick(origin, look, candidates, 10, 0.25)).to.equal(nil)
		end)

		it("should pick the nearest of several and ignore height", function()
			local candidates = {
				{ Key = "far", Position = Vector3.new(0, 0, -8) },
				{ Key = "near", Position = Vector3.new(1, 6, -3) },
			}
			expect(WhackTarget.Pick(origin, look, candidates, 10, 0.25)).to.equal("near")
		end)

		it("should return nil for a vertical look vector", function()
			local candidates = { { Key = "a", Position = Vector3.new(0, 0, -2) } }
			expect(WhackTarget.Pick(origin, Vector3.new(0, 1, 0), candidates, 10, 0.25)).to.equal(nil)
		end)
	end)
end
