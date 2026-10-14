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

	beforeEach(function()
		service._toggleDebounces = {}
		service.Client.Server = service
	end)

	afterEach(function()
		service._toggleDebounces = {}
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
end
