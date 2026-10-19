--[[
	Module: RealOrderService
	Description: Real-player orders (REVIVAL-001 M2-REALORDER, design 4.9): a
	             "Real customer!" bubble over the customer, double barista pay for
	             the first few orders from the same customer, and customer rewards.
--]]

---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> Dependencies

local Knit = require(Packages.Knit)
local Styles = require(Shared.UI.Styles)
local RealOrderConfig = require(Shared.Configuration.RealOrderConfig)
local Progression = require(Shared.Configuration.Progression)
local Rules = require(script.Parent.CustomerService.Rules)

---> Constants

local BUBBLE_NAME = "RealCustomerBubble"
local BUBBLE_SIZE = UDim2.fromOffset(200, 40)
local BUBBLE_OFFSET = Vector3.new(0, 3.5, 0)
local BUBBLE_MAX_DISTANCE_STUDS = 80
local HEARTS_TIMEOUT_SECONDS = 60
local HEART_BUTTONS = {
	{ Text = "1" },
	{ Text = "2" },
	{ Text = "3" },
	{ Text = "4" },
	{ Text = "5" },
}
local BUBBLE_TEXT = `Real customer!  ×{RealOrderConfig.PAY_MULT} pay`

---> Types

export type History = { [string]: { number } } -- "baristaId:customerId" -> timestamps

local RealOrderService = Knit.CreateService({
	Name = "RealOrderService",
	Client = {},
	_history = {} :: History,
	_rating = {} :: { [Player]: boolean },
})

---> Pure helpers

local function pairKey(baristaId: number, customerId: number): string
	return `{baristaId}:{customerId}`
end

-- Pay multiplier for the barista's next order from this customer: PAY_MULT while
-- they served that customer fewer than BONUS_ORDER_COUNT times in the window.
function RealOrderService.PayMultiplier(history: History, baristaId: number, customerId: number, now: number): number
	local stamps = history[pairKey(baristaId, customerId)]
	local recent = 0
	if stamps then
		for _, t in stamps do
			if now - t < RealOrderConfig.WINDOW_SECONDS then
				recent += 1
			end
		end
	end
	if recent < RealOrderConfig.BONUS_ORDER_COUNT then
		return RealOrderConfig.PAY_MULT
	end
	return 1
end

-- Records a serve and drops timestamps outside the window.
function RealOrderService.Record(history: History, baristaId: number, customerId: number, now: number)
	local key = pairKey(baristaId, customerId)
	local kept = {}
	for _, t in history[key] or {} do
		if now - t < RealOrderConfig.WINDOW_SECONDS then
			table.insert(kept, t)
		end
	end
	table.insert(kept, now)
	history[key] = kept
end

---> Bubble

local function removeBubble(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local gui = head and head:FindFirstChild(BUBBLE_NAME)
	if gui then
		gui:Destroy()
	end
end

-- Layout copied from Npc.luau buildBubble (STYLE 4.5), minus the patience bar.
local function addBubble(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or head:FindFirstChild(BUBBLE_NAME) then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = BUBBLE_NAME
	gui.Adornee = head
	gui.Size = BUBBLE_SIZE
	gui.StudsOffset = BUBBLE_OFFSET
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = BUBBLE_MAX_DISTANCE_STUDS

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Styles.CREAM
	card.BorderSizePixel = 0
	card.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Styles.CORNER_BUTTON
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Styles.GREEN
	stroke.Thickness = 2
	stroke.Parent = card

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(8, 4)
	label.Size = UDim2.new(1, -16, 1, -8)
	label.BackgroundTransparency = 1
	label.FontFace = Styles.FONT_FREDOKA
	label.TextColor3 = Styles.GREEN_DEEP
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = BUBBLE_TEXT
	label.Parent = card

	gui.Parent = head
end

---> Hearts

-- Maps a dialog choice to 1-5, or nil for anything else (dismissed or tampered).
function RealOrderService.ParseHearts(choice: any): number?
	if type(choice) ~= "string" then
		return nil
	end
	local n = tonumber(choice)
	if n and n == math.floor(n) and n >= 1 and n <= 5 then
		return n
	end
	return nil
end

-- One prompt per pick-up. DialogService only resolves a dialog for the player it was
-- sent to, and only once, so a customer can rate each order exactly once.
function RealOrderService:_askHearts(customer: Player, barista: Player)
	if self._rating[customer] then
		return
	end
	self._rating[customer] = true
	local name = string.gsub(barista.DisplayName, "[<>&]", "")
	local baristaId = barista.UserId
	self._dialog
		:CreateDialog(customer, "ButtonPrompt", {
			Title = "Rate your barista",
			Text = `How many hearts for <b>{name}</b>? (1-5)`,
			Buttons = HEART_BUTTONS,
			OffsetX = 0.1,
		}, HEARTS_TIMEOUT_SECONDS)
		:andThen(function(choice)
			local hearts = RealOrderService.ParseHearts(choice)
			local target = Players:GetPlayerByUserId(baristaId)
			if not hearts or not target then
				return
			end
			self._stats:IncrementStat(target, "HeartsReceived", hearts)
			self._stats:IncrementStat(target, "HeartsCount", 1)
		end)
		:catch(function(err)
			warn("[RealOrderService] Hearts prompt failed:", err)
		end)
		:finally(function()
			self._rating[customer] = nil
		end)
end

---> Handlers

function RealOrderService:_onOrderCreated(customerId: number)
	local customer = Players:GetPlayerByUserId(customerId)
	if customer then
		addBubble(customer)
	end
end

function RealOrderService:_onOrderPickedUp(
	customerId: number,
	barista: Player?,
	grade: any,
	specs: { any },
	tools: { Instance },
	items: { any }
)
	local customer = Players:GetPlayerByUserId(customerId)
	if customer then
		removeBubble(customer)
		-- The customer keeps the drink; "Served" is already set so it is never reused.
		for _, tool in tools do
			tool:SetAttribute("MadeBy", barista and barista.DisplayName or "")
			tool:SetAttribute("Served", true)
		end
		pcall(function()
			self._stats:IncrementStat(customer, "RegularOrders", 1)
		end)
		local ok, quests = pcall(Knit.GetService, "QuestService")
		if ok and quests and quests.Progress then
			pcall(function()
				quests:Progress(customer, "RealOrder")
			end)
		end
	end

	if not barista or #specs == 0 then
		return
	end

	local now = os.clock()
	local multiplier = RealOrderService.PayMultiplier(self._history, barista.UserId, customerId, now)
	RealOrderService.Record(self._history, barista.UserId, customerId, now)

	local pay = Rules.Payout(items, grade, 0, 0, false, false) * multiplier
	pcall(function()
		self._currency:Modify(barista, "BobaBucks", pay)
	end)
	pcall(function()
		local text = `+{pay} · Real customer ×{multiplier}`
		self._dialog:Notify(barista, { Title = "Real customer", Description = text, Text = text } :: any)
	end)
	pcall(function()
		self._progression:AddXp(barista, Progression.XP_PER_ITEM * #specs)
	end)
	pcall(function()
		Knit.GetService("QuestService"):AdvanceQuest(barista, "RegularOrders", 1)
	end)
end

function RealOrderService:KnitStart()
	self._stats = Knit.GetService("StatisticsService")
	self._currency = Knit.GetService("CurrencyService")
	self._dialog = Knit.GetService("DialogService")
	self._progression = Knit.GetService("ProgressionService")
	local orders = Knit.GetService("OrderService")

	orders.OrderCreated:Connect(function(customerId: number)
		self:_onOrderCreated(customerId)
	end)
	orders.OrderPickedUp:Connect(function(...)
		self:_onOrderPickedUp(...)
	end)
end

function RealOrderService:PlayerRemoving(player: Player)
	self._rating[player] = nil
	for key in self._history do
		local b, c = string.match(key, "^(%d+):(%d+)$")
		if b == tostring(player.UserId) or c == tostring(player.UserId) then
			self._history[key] = nil
		end
	end
end

return RealOrderService
