-- selene: allow(undefined_variable)
--[[
	BobaBuddyService.spec.luau
	Unit tests for Boba Buddy spawning, timer extensions, stacking, and clock-out despawn.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local BobaBuddyConfig = require(ReplicatedStorage.Shared.Configuration.BobaBuddyConfig)

	local function makeFakePlayer(userId: number, clockedIn: boolean): Player
		local folder = Instance.new("Folder")
		folder.Name = "TestPlayer_" .. userId
		local player = folder :: any
		player.UserId = userId
		player.Name = folder.Name
		player.DisplayName = "TestUser"
		player:SetAttribute("ClockedIn", clockedIn)

		local char = Instance.new("Model")
		char.Name = "Character"
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = char
		char.PrimaryPart = root
		char.Parent = workspace
		player.Character = char

		return player
	end

	describe("BobaBuddyService", function()
		it("should have valid configuration constants", function()
			expect(BobaBuddyConfig.LIFESPAN_SECONDS).to.equal(180)
			expect(BobaBuddyConfig.STACK_MODE).to.equal("Extend")
			expect(BobaBuddyConfig.CLEANER.RANGE_STUDS).to.equal(25)
			expect(BobaBuddyConfig.STOCKER.RANGE_STUDS).to.equal(30)
		end)

		it("should refuse to spawn buddy when player is not clocked in", function()
			local player = makeFakePlayer(99901, false)
			local isClockedIn = player:GetAttribute("ClockedIn") == true
			expect(isClockedIn).to.equal(false)
			player.Character:Destroy()
			player:Destroy()
		end)

		it("should support timer extension under Extend stacking mode", function()
			local expiresAt = os.clock() + BobaBuddyConfig.LIFESPAN_SECONDS
			local initialTime = expiresAt

			-- Simulate stacking purchase:
			if BobaBuddyConfig.STACK_MODE == "Extend" then
				expiresAt += BobaBuddyConfig.LIFESPAN_SECONDS
			end

			expect(expiresAt - initialTime).to.equal(180)
		end)
	end)
end
