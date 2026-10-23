-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	StarterBundleReceipts.spec.luau
	One-time Starter Bundle receipt actions (SEASON-PASS, 2026-10-23),
	fake-based like BobaBuckReceipts.spec.luau.
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local ProductIds = require(ReplicatedStorage.Shared.Configuration.ProductIds)
	local StarterBundleConfig = require(ReplicatedStorage.Shared.Configuration.StarterBundleConfig)
	local StarterBundleReceipts = require(ServerScriptService.Server.Modules.StarterBundleReceipts) :: any

	local FAKE_ID = 12345678

	local calls
	local originalGetCurrency = StarterBundleReceipts._getCurrencyService
	local originalId = ProductIds.StarterBundle

	local function makePlayerData()
		local data: any = {
			Currency = { BobaBucks = 10 },
			Inventory = { Items = { Capsules = {} } },
			StarterBundleClaimed = false,
		}
		function data:SetValue(path: { string }, value: any)
			local pointer = self
			for i = 1, #path - 1 do
				pointer = pointer[path[i]]
			end
			pointer[path[#path]] = value
		end
		return data
	end

	beforeEach(function()
		calls = {}
		ProductIds.StarterBundle = FAKE_ID
		StarterBundleReceipts._getCurrencyService = function()
			return {
				ApplyLoaded = function(_, player, playerData, currency, amount, reason)
					table.insert(calls, { player = player, currency = currency, amount = amount, reason = reason })
					playerData.Currency.BobaBucks += amount
				end,
			}
		end
	end)

	afterEach(function()
		StarterBundleReceipts._getCurrencyService = originalGetCurrency
		ProductIds.StarterBundle = originalId
	end)

	it("builds no actions while the product ID is nil", function()
		ProductIds.StarterBundle = nil
		local actions = StarterBundleReceipts.BuildActions()
		expect(next(actions)).to.equal(nil)
		expect(StarterBundleReceipts.IsStarterBundle(FAKE_ID)).to.equal(false)
	end)

	it("builds one action once the product ID is set", function()
		local actions = StarterBundleReceipts.BuildActions()
		expect(actions[FAKE_ID] ~= nil).to.equal(true)
		expect(actions[FAKE_ID].Name).to.equal("Starter Bundle")
		expect(StarterBundleReceipts.IsStarterBundle(FAKE_ID)).to.equal(true)
	end)

	it("returns false for an unknown product", function()
		local actions = StarterBundleReceipts.BuildActions()
		local ok = actions[FAKE_ID].Grant({ UserId = 1 }, { ProductId = 1 }, makePlayerData())
		expect(ok).to.equal(false)
		expect(#calls).to.equal(0)
	end)

	it("grants BB, both capsules and the flag, then returns true", function()
		local actions = StarterBundleReceipts.BuildActions()
		local data = makePlayerData()
		local ok = actions[FAKE_ID].Grant({ UserId = 1 }, { ProductId = FAKE_ID }, data)
		expect(ok).to.equal(true)
		expect(data.Currency.BobaBucks).to.equal(10 + StarterBundleConfig.BOBA_BUCKS)
		expect(#calls).to.equal(1)
		expect(calls[1].reason).to.equal("StarterBundle")
		expect(data.StarterBundleClaimed).to.equal(true)
		local names: { [string]: boolean } = {}
		local count = 0
		for _, item in data.Inventory.Items.Capsules do
			count += 1
			names[item.Name] = true
		end
		expect(count).to.equal(#StarterBundleConfig.CAPSULES)
		for _, capsuleName in StarterBundleConfig.CAPSULES do
			expect(names[capsuleName]).to.equal(true)
		end
	end)

	it("grants nothing when the profile has no capsule inventory", function()
		local actions = StarterBundleReceipts.BuildActions()
		local data = makePlayerData()
		data.Inventory.Items.Capsules = nil
		local ok = actions[FAKE_ID].Grant({ UserId = 1 }, { ProductId = FAKE_ID }, data)
		expect(ok).to.equal(false)
		expect(#calls).to.equal(0)
	end)
end
