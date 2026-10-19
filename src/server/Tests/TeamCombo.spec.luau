-- selene: allow(undefined_variable)
--[[
	TeamCombo.spec.luau
	TestEZ tests for the pure Team Combo rules (REVIVAL-001 M3-REM-C, DEC-028 E23, DEC-036 C1-C5):
	the server-wide chain and the pay bonus. The 60 s window itself lives in CustomerService
	(os.clock deadline + task.delay) and is not covered here: that module needs the authored
	world, so the window is checked by hand (see the evidence "Test for Jack" list).
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Rules = require(ServerScriptService.Server.Modules.CustomerService.Rules)
	local TeamComboConfig = require(ReplicatedStorage.Shared.Configuration.TeamComboConfig)

	describe("Rules.NextTeamChain", function()
		it("counts a successful serve of either grade", function()
			expect(Rules.NextTeamChain(0, "Perfect", 10)).to.equal(1)
			expect(Rules.NextTeamChain(4, "Close", 10)).to.equal(5)
		end)

		it("triggers on the serve that reaches the target and restarts at 0", function()
			local chain, triggered = Rules.NextTeamChain(9, "Perfect", 10)
			expect(chain).to.equal(0)
			expect(triggered).to.equal(true)
		end)

		it("does not trigger before the target", function()
			local _, triggered = Rules.NextTeamChain(8, "Close", 10)
			expect(triggered).to.equal(false)
		end)

		it("resets on a walkout", function()
			local chain, triggered = Rules.NextTeamChain(7, nil, 10)
			expect(chain).to.equal(0)
			expect(triggered).to.equal(false)
		end)

		it("triggers exactly once over ten serves", function()
			local chain, triggers = 0, 0
			for _ = 1, TeamComboConfig.CHAIN_TARGET do
				local triggered
				chain, triggered = Rules.NextTeamChain(chain, "Perfect", TeamComboConfig.CHAIN_TARGET)
				if triggered then
					triggers += 1
				end
			end
			expect(triggers).to.equal(1)
			expect(chain).to.equal(0)
		end)
	end)

	describe("Rules.TeamComboPay", function()
		it("pays x1.10 rounded inside the window", function()
			expect(Rules.TeamComboPay(10, true, TeamComboConfig.PAY_BONUS)).to.equal(11)
			expect(Rules.TeamComboPay(7, true, TeamComboConfig.PAY_BONUS)).to.equal(8) -- 7.7
		end)

		it("pays x1.0 outside the window", function()
			expect(Rules.TeamComboPay(10, false, TeamComboConfig.PAY_BONUS)).to.equal(10)
		end)

		it("stacks on Rush Hour: x2 then x1.10", function()
			local rush = 5 * 2
			expect(Rules.TeamComboPay(rush, true, TeamComboConfig.PAY_BONUS)).to.equal(11)
		end)
	end)

	describe("TeamComboConfig", function()
		it("matches DEC-028 E23", function()
			expect(TeamComboConfig.CHAIN_TARGET).to.equal(10)
			expect(TeamComboConfig.PAY_BONUS).to.equal(0.10)
			expect(TeamComboConfig.DURATION_SECONDS).to.equal(60)
		end)
	end)
end
