-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	Regulars.spec.luau
	TestEZ tests for the BIG-B5 Regulars rules (RegularsService/Rules): roster
	content, spawn gate, pick, favourite order, greeting and stamping. Pure; no
	Instances or authored content.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Rules = require(ServerScriptService.Server.Modules.RegularsService.Rules)
	local RegularsConfig = require(ReplicatedStorage.Shared.Configuration.RegularsConfig)
	local CustomerConfig = require(ReplicatedStorage.Shared.Configuration.CustomerConfig)
	local OrderSpec = require(ReplicatedStorage.Shared.Ordering.OrderSpec)
	local Titles = require(ReplicatedStorage.Shared.Configuration.Titles)
	local ProfileTemplate = require(ReplicatedStorage.Shared.Configuration.ProfileTemplate)

	describe("roster", function()
		it("has twelve regulars with unique ids and looks", function()
			expect(#RegularsConfig.ROSTER).to.equal(12)
			local ids, looks = {}, {}
			for _, regular in RegularsConfig.ROSTER do
				expect(ids[regular.Id]).to.equal(nil)
				expect(looks[regular.Look.Base]).to.equal(nil)
				ids[regular.Id] = true
				looks[regular.Look.Base] = true
			end
		end)

		it("only sets real HumanoidDescription properties in each look", function()
			for _, regular in RegularsConfig.ROSTER do
				local description = Instance.new("HumanoidDescription")
				for property, value in regular.Look.Description or {} do
					local ok = pcall(function()
						(description :: any)[property] = value
					end)
					expect(ok).to.equal(true)
				end
				description:Destroy()
			end
		end)

		it("only favours existing pool drinks, and each resolves through OrderSpec", function()
			for _, regular in RegularsConfig.ROSTER do
				expect(Rules.FavouriteEntry(regular)).never.to.equal(nil)
				local order = Rules.FavouriteOrder(regular, 99)
				expect(order).never.to.equal(nil)
				local spec = OrderSpec.FromOrderItem(order :: any)
				expect(spec).never.to.equal(nil)
			end
		end)

		it("grants a catalog title and the profile has the additive field", function()
			expect(Titles.Get(RegularsConfig.REWARD_TITLE)).never.to.equal(nil)
			expect(typeof(ProfileTemplate.Regulars.Visits)).to.equal("table")
			expect(ProfileTemplate.Regulars.RewardClaimed).to.equal(false)
		end)
	end)

	describe("ShouldSpawn", function()
		it("never spawns for a variant customer", function()
			expect(Rules.ShouldSpawn(0, 1000, nil, true)).to.equal(false)
		end)

		it("respects the server-wide gap", function()
			local gap = RegularsConfig.MIN_GAP_SECONDS
			expect(Rules.ShouldSpawn(0, 1000, 1000 - gap + 1, false)).to.equal(false)
			expect(Rules.ShouldSpawn(0, 1000, 1000 - gap, false)).to.equal(true)
		end)

		it("rolls against SPAWN_CHANCE", function()
			expect(Rules.ShouldSpawn(RegularsConfig.SPAWN_CHANCE - 0.001, 0, nil, false)).to.equal(true)
			expect(Rules.ShouldSpawn(RegularsConfig.SPAWN_CHANCE, 0, nil, false)).to.equal(false)
		end)
	end)

	describe("Pick", function()
		it("skips regulars already in the cafe", function()
			local present = {}
			for i = 1, 11 do
				present[RegularsConfig.ROSTER[i].Id] = true
			end
			local regular = Rules.Pick(0.5, 1, present, {})
			expect(regular).never.to.equal(nil)
			expect((regular :: any).Id).to.equal(RegularsConfig.ROSTER[12].Id)
		end)

		it("returns nil when everyone is present", function()
			local present = {}
			for _, regular in RegularsConfig.ROSTER do
				present[regular.Id] = true
			end
			expect(Rules.Pick(0.5, 0, present, {})).to.equal(nil)
		end)

		it("prefers an unmet regular under the bias roll", function()
			local unmet = { [RegularsConfig.ROSTER[7].Id] = true }
			local regular = Rules.Pick(0.99, 0, {}, unmet)
			expect((regular :: any).Id).to.equal(RegularsConfig.ROSTER[7].Id)
		end)

		it("picks from the whole roster above the bias roll", function()
			local unmet = { [RegularsConfig.ROSTER[7].Id] = true }
			local regular = Rules.Pick(0, 0.999, {}, unmet)
			expect((regular :: any).Id).to.equal(RegularsConfig.ROSTER[1].Id)
		end)
	end)

	describe("FavouriteOrder", function()
		it("returns nil below the drink's level and fixes the size", function()
			local kenji = Rules.Get("Kenji") :: any
			local entry = Rules.FavouriteEntry(kenji) :: any
			expect(Rules.FavouriteOrder(kenji, entry.MinLevel - 1)).to.equal(nil)
			local order = Rules.FavouriteOrder(kenji, entry.MinLevel) :: any
			expect(order.Item).to.equal(entry.OrderItem.Item)
			expect(order.CustomInfo.Size).to.equal(kenji.Size)
		end)

		it("leaves unsized drinks without a size and never edits the pool", function()
			local gus = Rules.Get("Gus") :: any
			local order = Rules.FavouriteOrder(gus, 1) :: any
			expect(order.CustomInfo.Size).to.equal(nil)
			order.CustomInfo.Size = "Large"
			for _, entry in CustomerConfig.ORDER_POOL do
				expect(entry.OrderItem.CustomInfo.Size).to.equal(nil)
			end
		end)
	end)

	describe("Greeting", function()
		local mabel = Rules.Get("Mabel") :: any

		it("greets by player name after the first visit", function()
			local line = Rules.Greeting(mabel, "Jack", true, true, 0)
			expect(line:find("Jack", 1, true)).never.to.equal(nil)
			expect(line:find(Rules.FavouriteLabel(mabel), 1, true)).never.to.equal(nil)
		end)

		it("introduces themselves on the first visit", function()
			local line = Rules.Greeting(mabel, "Jack", false, true, 0)
			expect(line:find("Mabel", 1, true)).never.to.equal(nil)
			expect(line:find("Jack", 1, true)).to.equal(nil)
		end)

		it("asks for a surprise when the favourite is locked", function()
			local line = Rules.Greeting(mabel, "Jack", true, false, 0)
			expect(line:find("Surprise", 1, true)).never.to.equal(nil)
			expect(line:find("{", 1, true)).to.equal(nil)
		end)
	end)

	describe("Stamp", function()
		it("counts the first visit and later visits", function()
			local first = Rules.Stamp({}, "Mabel", false) :: any
			expect(first.First).to.equal(true)
			expect(first.Visits).to.equal(1)
			expect(first.Stamped).to.equal(1)
			local again = Rules.Stamp({ Mabel = 1 }, "Mabel", false) :: any
			expect(again.First).to.equal(false)
			expect(again.Visits).to.equal(2)
			expect(again.Stamped).to.equal(1)
		end)

		it("ignores ids outside the roster", function()
			expect(Rules.Stamp({}, "Nobody", false)).to.equal(nil)
			expect(Rules.Count({ Nobody = 3 })).to.equal(0)
		end)

		it("completes once, on the last new stamp", function()
			local visits = {}
			for i = 1, 11 do
				visits[RegularsConfig.ROSTER[i].Id] = 1
			end
			local last = RegularsConfig.ROSTER[12].Id
			local done = Rules.Stamp(visits, last, false) :: any
			expect(done.Completed).to.equal(true)
			expect(done.Stamped).to.equal(12)
			local claimed = Rules.Stamp(visits, last, true) :: any
			expect(claimed.Completed).to.equal(false)
		end)

		it("does not edit the visits it is given", function()
			local visits = { Mabel = 2 }
			Rules.Stamp(visits, "Mabel", false)
			expect(visits.Mabel).to.equal(2)
		end)
	end)
end
