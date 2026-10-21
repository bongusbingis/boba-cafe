-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	PourMoments.spec.luau
	TAKEOVER-FIX 1: AwaitPour must resume its caller exactly once and leave no pending
	state on every path (timeout, walk-away, un-equip, leave, tap). A stranded caller
	pins InteractionRunner's per-player station lock until rejoin.
	Uses a fake player table and unparented instances; the window is shortened by
	patching KitchenConfig.POUR_METER for the duration of each case.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)
	local PourMoments = require(ServerScriptService.Server.Modules.KitchenService.PourMoments)

	local SHORT_DURATION = 0.2
	local savedDuration, savedAllowance

	local function fakeService()
		local signal = {
			Fire = function() end,
		}
		return { Client = { PourWindowOpened = signal, PourResolved = signal } }
	end

	local function rig(hrpOffset: Vector3)
		local character = Instance.new("Model")
		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Position = hrpOffset
		hrp.Parent = character
		local tool = Instance.new("Tool")
		tool.Parent = character

		local station = Instance.new("Model")
		local base = Instance.new("Part")
		base.Position = Vector3.zero
		base.Parent = station
		station.PrimaryPart = base

		local player = { Character = character, Name = "FakePourPlayer" }
		return player :: any, tool, station, character
	end

	-- Runs AwaitPour on its own thread; returns a probe to read the result.
	local function startPour(pours, player, station)
		local probe = { done = false, tier = "unset" :: any }
		task.spawn(function()
			probe.tier = pours:AwaitPour(player, { SkillMoment = true }, station)
			probe.done = true
		end)
		return probe
	end

	local function waitFor(probe, seconds: number)
		local deadline = os.clock() + seconds
		while not probe.done and os.clock() < deadline do
			task.wait(0.05)
		end
	end

	local function expectNoPending(pours, player)
		expect(pours._windows[player]).to.equal(nil)
		expect(pours._pendingThreads[player]).to.equal(nil)
		expect(pours._pendingCancels[player]).to.equal(nil)
		expect(pours._pendingFinish[player]).to.equal(nil)
	end

	beforeEach(function()
		savedDuration = KitchenConfig.POUR_METER.DURATION_SECONDS
		savedAllowance = KitchenConfig.POUR_METER.LATENCY_ALLOWANCE_SECONDS
		KitchenConfig.POUR_METER.DURATION_SECONDS = SHORT_DURATION
		KitchenConfig.POUR_METER.LATENCY_ALLOWANCE_SECONDS = 0.05
	end)

	afterEach(function()
		KitchenConfig.POUR_METER.DURATION_SECONDS = savedDuration
		KitchenConfig.POUR_METER.LATENCY_ALLOWANCE_SECONDS = savedAllowance
	end)

	describe("AwaitPour release paths", function()
		it("resolves Good (no downgrade) on timeout and clears all pending state", function()
			local pours = PourMoments.new(fakeService() :: any)
			local player, tool, station = rig(Vector3.new(2, 0, 0))
			pours._unlocked[player] = true
			local probe = startPour(pours, player, station)
			waitFor(probe, 2)
			expect(probe.done).to.equal(true)
			expect(probe.tier).to.equal("Good")
			expect(tool:GetAttribute("PoorPours")).to.equal(nil)
			expect(tool:GetAttribute("PerfectPours")).to.equal(nil)
			expectNoPending(pours, player)
		end)

		it("cancels (nil) when the player walks away", function()
			local pours = PourMoments.new(fakeService() :: any)
			KitchenConfig.POUR_METER.DURATION_SECONDS = 5
			local player, _, station, character = rig(Vector3.new(2, 0, 0))
			pours._unlocked[player] = true
			local probe = startPour(pours, player, station)
			character.HumanoidRootPart.Position = Vector3.new(500, 0, 0)
			waitFor(probe, 2)
			expect(probe.done).to.equal(true)
			expect(probe.tier).to.equal(nil)
			expectNoPending(pours, player)
		end)

		it("cancels (nil) when the tool is unequipped or the character dies", function()
			local pours = PourMoments.new(fakeService() :: any)
			KitchenConfig.POUR_METER.DURATION_SECONDS = 5
			local player, tool, station = rig(Vector3.new(2, 0, 0))
			pours._unlocked[player] = true
			local probe = startPour(pours, player, station)
			tool.Parent = nil
			waitFor(probe, 1)
			expect(probe.done).to.equal(true)
			expect(probe.tier).to.equal(nil)
			expectNoPending(pours, player)
		end)

		it("cancels (nil) when the player leaves", function()
			local pours = PourMoments.new(fakeService() :: any)
			KitchenConfig.POUR_METER.DURATION_SECONDS = 5
			local player, _, station = rig(Vector3.new(2, 0, 0))
			pours._unlocked[player] = true
			local probe = startPour(pours, player, station)
			pours:_cancelPending(player)
			waitFor(probe, 1)
			expect(probe.done).to.equal(true)
			expect(probe.tier).to.equal(nil)
			expectNoPending(pours, player)
		end)

		it("resolves on a tap and ignores a late tap", function()
			local pours = PourMoments.new(fakeService() :: any)
			KitchenConfig.POUR_METER.DURATION_SECONDS = 5
			local player, _, station = rig(Vector3.new(2, 0, 0))
			pours._unlocked[player] = true
			local probe = startPour(pours, player, station)
			local windowId = pours._windows[player].Id
			local tier = pours:ReportTap(player, windowId, 0.1)
			expect(tier).never.to.equal(nil)
			waitFor(probe, 1)
			expect(probe.done).to.equal(true)
			expect(probe.tier).to.equal(tier)
			expectNoPending(pours, player)
			expect(pours:ReportTap(player, windowId, 0.1)).to.equal(nil)
		end)

		it("a second pour cancels the first one instead of stranding it", function()
			local pours = PourMoments.new(fakeService() :: any)
			local player, _, station = rig(Vector3.new(2, 0, 0))
			pours._unlocked[player] = true
			local first = startPour(pours, player, station)
			local second = startPour(pours, player, station)
			waitFor(first, 1)
			expect(first.done).to.equal(true)
			expect(first.tier).to.equal(nil)
			waitFor(second, 2)
			expect(second.tier).to.equal("Good")
			expectNoPending(pours, player)
		end)
	end)
end
