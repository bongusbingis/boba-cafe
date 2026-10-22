-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	PassCosmetics.spec.luau
	TestEZ tests for the cosmetic pass perk helpers (VIP chat colour, Rainbow Pack).
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PassCosmetics = require(ReplicatedStorage.Shared.Configuration.PassCosmetics)
	local Styles = require(ReplicatedStorage.Shared.UI.Styles)

	describe("VIP chat colour", function()
		it("uses the main UI green", function()
			expect(PassCosmetics.VIP_CHAT_COLOR).to.equal(Styles.GREEN)
			expect(PassCosmetics.ToHex(Color3.fromRGB(143, 169, 127))).to.equal("#8FA97F")
		end)

		it("wraps only the message text in a font colour tag", function()
			expect(PassCosmetics.ColorizeChatText("hi", Color3.fromRGB(143, 169, 127))).to.equal(
				'<font color="#8FA97F">hi</font>'
			)
		end)
	end)

	describe("Rainbow Pack", function()
		it("cycles at least two colours so the nametag animates", function()
			expect(#PassCosmetics.RAINBOW_ANIMATION.Frames >= 2).to.equal(true)
		end)
	end)
end
