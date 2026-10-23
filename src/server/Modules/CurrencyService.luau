local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Config = Shared:WaitForChild("Configuration")

local Knit = require(Packages.Knit)
local ProfileTemplate = require(Config.ProfileTemplate)

---> constants
local DATA_TIMEOUT_SECONDS = 10

-- BB credits that are not play-earned and so never count toward the MostBobaBucks board (DEC-035 Q4).
-- Robux pack receipts (RobuxPack) are excluded: bought BB must not buy a leaderboard spot (DEC-035 Q8).
-- PromoCode and ItemSell grants are excluded too (DEC-038 Q14): codes and item sales are not play-earned.
local LEADERBOARD_EXCLUDED_REASONS: { [string]: boolean } = {
	QuestRerollRefund = true,
	RobuxPack = true,
	PromoCode = true,
	ItemSell = true,
	-- SEASON-PASS: Robux-paid BB must not buy leaderboard spots (DEC-035 Q8).
	SeasonPass = true,
	StarterBundle = true,
}

---> module declaration
local CurrencyService = Knit.CreateService({
	Name = "CurrencyService",
})

--- Resolves another Knit service. Indirection exists so specs can substitute fakes without starting Knit.
function CurrencyService:_getService(name: string)
	return Knit.GetService(name)
end

function CurrencyService:Modify(player: Player, type: "BobaBucks" | "Points", amount: number, reason: string?)
	if not ProfileTemplate.Currency[type] then
		warn(`Invalid currency type: {type}`)
		return
	end

	if amount == 0 then
		warn("Amount must be non-zero")
		return
	end

	self:_getService("DataService"):GetDataAsync(player):andThen(function(playerData)
		self:ApplyLoaded(player, playerData, type, amount, reason)
	end)
end

--- Applies a credit/debit to already-loaded player data. Does not yield, so a receipt grant can apply it
--- synchronously and record the receipt back to back. Same stats, leaderboard feed and analytics as Modify.
function CurrencyService:ApplyLoaded(
	player: Player,
	playerData: any,
	type: "BobaBucks" | "Points",
	amount: number,
	reason: string?
)
	local current = playerData.Currency[type]
	if not current then
		warn(`Player {player.Name} does not have currency type: {type}`)
		return
	end

	if type == "BobaBucks" then
		local statisticsService = self:_getService("StatisticsService")
		local statToIncrement = amount > 0 and "BobaBucksEarned" or "BobaBucksSpent"
		statisticsService:IncrementStat(player, statToIncrement, math.abs(amount))
	end

	playerData:SetValue({ "Currency", type }, current + amount)
	if type == "BobaBucks" and amount > 0 and not LEADERBOARD_EXCLUDED_REASONS[reason or ""] then
		-- Lazy lookup: a leaderboard failure must never break a payment.
		pcall(function()
			self:_getService("LeaderboardService"):IncrementStat(player, "MostBobaBucks", amount)
		end)
	end
	pcall(function()
		local a = self:_getService("AnalyticsEvents")
		a:Economy(player, amount > 0, amount, current + amount, reason or "Gameplay", type)
	end)
end

--- Atomically checks the balance and deducts `amount`. Yields while the player's data loads.
--- The check and the deduction happen back to back without yielding, so concurrent spends cannot overdraw.
--- Returns `(true)` on success, or `(false, reason)` when nothing was deducted.
function CurrencyService:TrySpendAsync(
	player: Player,
	currencyType: "BobaBucks" | "Points",
	amount: number
): (boolean, string?)
	if typeof(currencyType) ~= "string" or ProfileTemplate.Currency[currencyType] == nil then
		warn(`[CurrencyService] Invalid currency type: {tostring(currencyType)}`)
		return false, "InvalidCurrency"
	end

	-- Positive whole numbers only; also rejects NaN and infinity (they fail the floor comparison).
	if typeof(amount) ~= "number" or amount <= 0 or amount ~= math.floor(amount) or amount == math.huge then
		warn(`[CurrencyService] Invalid spend amount: {tostring(amount)}`)
		return false, "InvalidAmount"
	end

	local ok, playerData = self:_getService("DataService"):GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()
	if not ok or not playerData then
		return false, "NoData"
	end

	-- No yields below this line: the balance read and the write are one atomic step.
	local current = playerData.Currency[currencyType]
	if typeof(current) ~= "number" then
		warn(`[CurrencyService] Player {player.Name} does not have currency type: {currencyType}`)
		return false, "InvalidCurrency"
	end

	if current < amount then
		return false, "InsufficientFunds"
	end

	playerData:SetValue({ "Currency", currencyType }, current - amount)

	if currencyType == "BobaBucks" then
		self:_getService("StatisticsService"):IncrementStat(player, "BobaBucksSpent", amount)
	end

	pcall(function()
		local a = self:_getService("AnalyticsEvents")
		a:Economy(player, false, amount, current - amount, "Shop", currencyType)
	end)

	return true
end

return CurrencyService
