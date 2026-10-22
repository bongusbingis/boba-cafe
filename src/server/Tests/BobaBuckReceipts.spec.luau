-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	BobaBuckReceipts.spec.luau
	Robux Boba Bucks pack receipt actions (PRODUCT-WIRE, Jack 2026-10-21).
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local ProductIds = require(ReplicatedStorage.Shared.Configuration.ProductIds)
	local BobaBuckReceipts = require(ServerScriptService.Server.Modules.BobaBuckReceipts) :: any

	local EXPECTED = {
		Pack50 = 50,
		Pack150 = 150,
		Pack500 = 500,
		Pack1000 = 1000,
		Pack5000 = 5000,
	}

	local calls
	local originalGetCurrency = BobaBuckReceipts._getCurrencyService

	beforeEach(function()
		calls = {}
		BobaBuckReceipts._getCurrencyService = function()
			return {
				ApplyLoaded = function(_, player, playerData, currency, amount, reason)
					table.insert(calls, { player = player, currency = currency, amount = amount, reason = reason })
					playerData.Currency.BobaBucks += amount
				end,
			}
		end
	end)

	afterEach(function()
		BobaBuckReceipts._getCurrencyService = originalGetCurrency
	end)

	it("maps every configured pack to its size", function()
		local actions = BobaBuckReceipts.BuildActions()
		for key, amount in EXPECTED do
			local id = (ProductIds.BobaBucks :: any)[key]
			expect(typeof(id)).to.equal("number")
			expect(BobaBuckReceipts.GetAmount(id)).to.equal(amount)
			expect(actions[id] ~= nil).to.equal(true)
		end
	end)

	it("returns nil for an unknown product", function()
		expect(BobaBuckReceipts.GetAmount(1)).to.equal(nil)
	end)

	it("grants the pack amount with the RobuxPack reason and returns true", function()
		local id = ProductIds.BobaBucks.Pack500
		local action = BobaBuckReceipts.BuildActions()[id]
		local data = { Currency = { BobaBucks = 10 } }
		local ok = action.Grant({ UserId = 1 }, { ProductId = id }, data)
		expect(ok).to.equal(true)
		expect(data.Currency.BobaBucks).to.equal(510)
		expect(#calls).to.equal(1)
		expect(calls[1].reason).to.equal("RobuxPack")
		expect(calls[1].amount).to.equal(500)
	end)

	it("grants nothing when the profile has no balance", function()
		local id = ProductIds.BobaBucks.Pack50
		local action = BobaBuckReceipts.BuildActions()[id]
		local ok = action.Grant({ UserId = 1 }, { ProductId = id }, { Currency = {} })
		expect(ok).to.equal(false)
		expect(#calls).to.equal(0)
	end)
end
