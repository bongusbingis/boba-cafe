-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	CafeUpgradeService.spec.luau
	BIG-B2 Cafe Upgrades: config helpers and the server-authoritative purchase path.
	The service's state tables are swapped for fresh ones per test and its world/broadcast
	hook (_onLevelApplied) is stubbed, so a live Studio server is left untouched.
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local CafeUpgradeConfig = require(ReplicatedStorage.Shared.Configuration.CafeUpgradeConfig)
	local service = require(ServerScriptService.Server.Modules.CafeUpgradeService) :: any

	describe("CafeUpgradeConfig", function()
		it("has unique ids, at least one level each, and positive whole prices", function()
			local seen = {}
			for _, upgrade in CafeUpgradeConfig.UPGRADES do
				expect(seen[upgrade.Id]).to.equal(nil)
				seen[upgrade.Id] = true
				expect(#upgrade.Levels >= 1).to.equal(true)
				for _, level in upgrade.Levels do
					expect(level.Price > 0).to.equal(true)
					expect(level.Price).to.equal(math.floor(level.Price))
				end
			end
		end)

		it("gives every upgrade a placement", function()
			local p = CafeUpgradeConfig.PLACEMENT
			expect(p.Board).to.be.ok()
			expect(p.TipJar).to.be.ok()
			expect(p.Jukebox).to.be.ok()
			local plants = CafeUpgradeConfig.GetUpgrade("Plants")
			local lights = CafeUpgradeConfig.GetUpgrade("Lights")
			expect(#p.Plants >= #(plants :: any).Levels * CafeUpgradeConfig.PLANTS_PER_LEVEL).to.equal(true)
			expect(#p.Lights >= #(lights :: any).Levels).to.equal(true)
		end)

		it("has a tip-jar chance for every Tip Jar level", function()
			local tipJar = CafeUpgradeConfig.GetUpgrade("TipJar") :: any
			expect(#CafeUpgradeConfig.TIP_JAR_CHANCE).to.equal(#tipJar.Levels)
		end)

		it("GetNextLevel walks the levels and stops at max", function()
			local level, price = CafeUpgradeConfig.GetNextLevel("Plants", 0)
			expect(level).to.equal(1)
			expect(price).to.equal(CafeUpgradeConfig.UPGRADES[1].Levels[1].Price)
			local maxLevel = #(CafeUpgradeConfig.GetUpgrade("Plants") :: any).Levels
			expect(CafeUpgradeConfig.GetNextLevel("Plants", maxLevel)).to.equal(nil)
			expect(CafeUpgradeConfig.GetNextLevel("Nope", 0)).to.equal(nil)
			expect(CafeUpgradeConfig.GetNextLevel(42, 0)).to.equal(nil)
		end)

		it("ButtonLabel is unique per upgrade and shows Maxed at the top level", function()
			local labels = {}
			for _, upgrade in CafeUpgradeConfig.UPGRADES do
				local label = CafeUpgradeConfig.ButtonLabel(upgrade, 0)
				expect(labels[label]).to.equal(nil)
				labels[label] = true
				local maxed = CafeUpgradeConfig.ButtonLabel(upgrade, #upgrade.Levels)
				expect(string.find(maxed, "Maxed", 1, true) ~= nil).to.equal(true)
			end
		end)

		it("TipJarExtra pays only under the level's chance", function()
			expect(CafeUpgradeConfig.TipJarExtra(nil, 0)).to.equal(0)
			expect(CafeUpgradeConfig.TipJarExtra(0, 0)).to.equal(0)
			local chance = CafeUpgradeConfig.TIP_JAR_CHANCE[1]
			expect(CafeUpgradeConfig.TipJarExtra(1, chance - 0.001)).to.equal(CafeUpgradeConfig.TIP_JAR_EXTRA)
			expect(CafeUpgradeConfig.TipJarExtra(1, chance)).to.equal(0)
			-- Levels above the table clamp to the last chance.
			local last = CafeUpgradeConfig.TIP_JAR_CHANCE[#CafeUpgradeConfig.TIP_JAR_CHANCE]
			expect(CafeUpgradeConfig.TipJarExtra(99, last - 0.001)).to.equal(CafeUpgradeConfig.TIP_JAR_EXTRA)
		end)

		it("PlaqueLines lists newest first and caps the count", function()
			local entries = {}
			for i = 1, 5 do
				table.insert(entries, { Name = `P{i}`, UpgradeName = "Jukebox", Level = 1 })
			end
			local lines = CafeUpgradeConfig.PlaqueLines(entries, 3)
			expect(#lines).to.equal(3)
			expect(string.find(lines[1], "P5", 1, true) ~= nil).to.equal(true)
			expect(string.find(lines[3], "P3", 1, true) ~= nil).to.equal(true)
		end)
	end)

	describe("CafeUpgradeService:TryPurchaseAsync", function()
		local saved
		local balance
		local spendCalls
		local applied

		local player = { Name = "Tester", DisplayName = "Tester", UserId = 1 } :: any

		beforeEach(function()
			saved = {
				levels = service._levels,
				contributions = service._contributions,
				pending = service._pending,
				getService = service._getService,
				onLevelApplied = service._onLevelApplied,
			}
			service._levels = {}
			service._contributions = {}
			service._pending = {}
			balance = 1000
			spendCalls = 0
			applied = {}

			local currency = {
				TrySpendAsync = function(_, _player, currencyType, amount)
					spendCalls += 1
					if currencyType ~= "BobaBucks" then
						return false, "InvalidCurrency"
					end
					if balance < amount then
						return false, "InsufficientFunds"
					end
					balance -= amount
					return true
				end,
			}
			service._getService = function(_, name)
				if name == "CurrencyService" then
					return currency
				end
				error("unexpected service " .. name)
			end
			service._onLevelApplied = function(_, id, level, _player)
				table.insert(applied, { Id = id, Level = level })
			end
		end)

		afterEach(function()
			service._levels = saved.levels
			service._contributions = saved.contributions
			service._pending = saved.pending
			service._getService = saved.getService
			service._onLevelApplied = saved.onLevelApplied
		end)

		it("spends the level price, raises the level, and credits the buyer", function()
			local price = (CafeUpgradeConfig.GetUpgrade("Plants") :: any).Levels[1].Price
			local ok = service:TryPurchaseAsync(player, "Plants", 1)
			expect(ok).to.equal(true)
			expect(balance).to.equal(1000 - price)
			expect(service:GetLevel("Plants")).to.equal(1)
			expect(#service._contributions).to.equal(1)
			expect(service._contributions[1].Name).to.equal("Tester")
			expect(#applied).to.equal(1)
			expect(applied[1].Level).to.equal(1)
		end)

		it("charges nothing and changes nothing when funds are short", function()
			balance = 10
			local ok, reason = service:TryPurchaseAsync(player, "Jukebox")
			expect(ok).to.equal(false)
			expect(reason).to.equal("InsufficientFunds")
			expect(service:GetLevel("Jukebox")).to.equal(0)
			expect(#applied).to.equal(0)
		end)

		it("rejects unknown ids without spending", function()
			local ok, reason = service:TryPurchaseAsync(player, "FreeMoney")
			expect(ok).to.equal(false)
			expect(reason).to.equal("UnknownUpgrade")
			expect(spendCalls).to.equal(0)
		end)

		it("rejects a stale menu choice without spending", function()
			service._levels.Lights = 1
			local ok, reason = service:TryPurchaseAsync(player, "Lights", 1)
			expect(ok).to.equal(false)
			expect(reason).to.equal("Changed")
			expect(spendCalls).to.equal(0)
		end)

		it("rejects a maxed upgrade without spending", function()
			service._levels.Lights = #(CafeUpgradeConfig.GetUpgrade("Lights") :: any).Levels
			local ok, reason = service:TryPurchaseAsync(player, "Lights")
			expect(ok).to.equal(false)
			expect(reason).to.equal("Maxed")
			expect(spendCalls).to.equal(0)
		end)

		it("refuses a second buyer while a purchase of the same upgrade is pending", function()
			service._pending.TipJar = true
			local ok, reason = service:TryPurchaseAsync(player, "TipJar")
			expect(ok).to.equal(false)
			expect(reason).to.equal("Busy")
			expect(spendCalls).to.equal(0)
		end)

		it("clears the pending lock after the spend", function()
			service:TryPurchaseAsync(player, "TipJar")
			expect(service._pending.TipJar).to.equal(nil)
			balance = 0
			service:TryPurchaseAsync(player, "TipJar")
			expect(service._pending.TipJar).to.equal(nil)
		end)
	end)
end
