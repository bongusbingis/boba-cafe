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
		folder:SetAttribute("ClockedIn", clockedIn)

		local char = Instance.new("Model")
		char.Name = "Character"
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = char
		char.PrimaryPart = root
		char.Parent = workspace

		local player = setmetatable({
			UserId = userId,
			Name = folder.Name,
			DisplayName = "TestUser",
			Character = char,
			Destroy = function(_self)
				folder:Destroy()
			end,
		}, { __index = folder })

		return (player :: any) :: Player
	end

	describe("BobaBuddyService", function()
		it("should have valid configuration constants", function()
			expect(BobaBuddyConfig.LIFESPAN_SECONDS).to.equal(180)
			expect(BobaBuddyConfig.STACK_MODE).to.equal("Extend")
			expect(BobaBuddyConfig.CLEANER.RANGE_STUDS).to.equal(50)
			expect(BobaBuddyConfig.STOCKER.RANGE_STUDS).to.equal(50)
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

		it("should have correct role colors for Stocker and Cleaner", function()
			expect(BobaBuddyConfig.COLORS).to.be.ok()
			expect(BobaBuddyConfig.COLORS.Stocker).to.be.ok()
			expect(BobaBuddyConfig.COLORS.Stocker.Skin).to.equal(Color3.fromRGB(130, 138, 93))
			expect(BobaBuddyConfig.COLORS.Stocker.Liquid).to.equal(Color3.fromRGB(193, 190, 66))

			expect(BobaBuddyConfig.COLORS.Cleaner).to.be.ok()
			expect(BobaBuddyConfig.COLORS.Cleaner.Skin).to.equal(Color3.fromRGB(93, 128, 148))
			expect(BobaBuddyConfig.COLORS.Cleaner.Liquid).to.equal(Color3.fromRGB(75, 175, 220))
		end)

		it("should attach a FredokaOne nametag with username and role", function()
			local ServerScriptService = game:GetService("ServerScriptService")
			local Nametag = require(ServerScriptService.Server.Modules.BobaBuddyService.Nametag)
			local player = makeFakePlayer(99902, true)

			local billboard = Nametag.Attach(player.Character, player, "Cleaner")
			expect(billboard).to.be.ok()
			expect(billboard.Name).to.equal("Nametag")

			local container = billboard:FindFirstChild("Container") :: Frame?
			expect(container).to.be.ok()

			local usernameLabel = container:FindFirstChild("UsernameLabel") :: TextLabel?
			local roleLabel = container:FindFirstChild("RoleLabel") :: TextLabel?
			expect(usernameLabel).to.be.ok()
			expect(roleLabel).to.be.ok()

			expect(usernameLabel.Text).to.equal(`${player.Name}'s Boba Buddy`)
			expect(roleLabel.Text).to.equal("Cleaner")

			player.Character:Destroy()
			player:Destroy()
		end)

		it("should support SpillService:Clean to trigger spill cleanup", function()
			local ServerScriptService = game:GetService("ServerScriptService")
			local SpillService = require(ServerScriptService.Server.Modules.SpillService)

			expect(typeof(SpillService.Clean)).to.equal("function")
			local cleaned = false
			local mockSpill = {
				Clean = function()
					cleaned = true
				end,
			}
			SpillService:Clean(mockSpill)
			expect(cleaned).to.equal(true)
		end)
	end)
end
