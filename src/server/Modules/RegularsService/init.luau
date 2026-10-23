--!strict
--[[
	Module: RegularsService
	Description: BIG-B5 Regulars collection. Named regulars (RegularsConfig.ROSTER)
	             sometimes walk in as NPC customers with a fixed look, order their
	             favourite drink, greet the barista by name once they have met, and
	             stamp the barista's Regulars book on every serve. Stamping all of them
	             pays the completion reward once (Boba Bucks + a manual title).

	CustomerService calls three hooks (all guarded there; a failure means a normal NPC):
	  RollSpawn(hasVariant)                 -> Regular?  at spawn, before the rig is built
	  Attach(npc, regular)                  tags the model (RegularId, BuiltBy), names the prompt
	  OrderFor(npc, player, order, scripted) -> OrderItem? at Take Order; also says the greeting
	Stamps come from CustomerService.CustomerLeft ("Served"), credited to the assignee.

	Profile (additive): Regulars = { Visits = { [id] = serves }, RewardClaimed = false }.
	Client: GetBook() -> the page model; BookChanged fires after a stamp.
--]]

---> services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies

local Knit = require(Packages.Knit)
local RegularsConfig = require(Shared.Configuration.RegularsConfig)
local Titles = require(Shared.Configuration.Titles)
local Rules = require(script.Rules)

---> constants

local BUILT_BY = "REVIVAL-001-BIG-B5"
local DATA_TIMEOUT_SECONDS = 10
local SPEECH_SECONDS = 4

---> private

local warned: { [string]: boolean } = {}
local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(message)
	end
end

local function formatThousands(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- The barista-facing speech line in the NPC bubble (the same Speech label Npc._say uses).
local function say(model: Model, text: string)
	local gui = model:FindFirstChild("OrderBubble")
	local speech = if gui ~= nil then gui:FindFirstChild("Speech") else nil
	if speech == nil or not speech:IsA("TextLabel") then
		return
	end
	speech.Text = text
	speech.Visible = true
	task.delay(SPEECH_SECONDS, function()
		if speech.Parent ~= nil and speech.Text == text then
			speech.Visible = false
		end
	end)
end

---> service

local RegularsService = Knit.CreateService({
	Name = "RegularsService",
	Client = {
		BookChanged = Knit.CreateSignal(),
	},

	_visits = {} :: { [Player]: { [string]: number } }, -- cached copy of each loaded profile's Visits
	_present = {} :: { [string]: boolean }, -- regular ids in the cafe right now
	_lastSpawn = nil :: number?,
	_shift = nil :: any,
})

---> hooks (CustomerService)

-- At spawn: a regular for the next customer, or nil. Never yields.
function RegularsService:RollSpawn(hasVariant: boolean): Rules.Regular?
	local now = os.clock()
	if not Rules.ShouldSpawn(math.random(), now, self._lastSpawn, hasVariant) then
		return nil
	end
	local unmet: { [string]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local visits = self._visits[player]
		if visits ~= nil and self:_isClockedIn(player) then
			for _, regular in RegularsConfig.ROSTER do
				if (visits[regular.Id] or 0) == 0 then
					unmet[regular.Id] = true
				end
			end
		end
	end
	local regular = Rules.Pick(math.random(), math.random(), self._present, unmet)
	if regular ~= nil then
		self._lastSpawn = now
	end
	return regular
end

-- After Npc.new: tags the model and keeps the prompt and greeting bubble named.
function RegularsService:Attach(npc: any, regular: Rules.Regular)
	local model: Model = npc.Model
	self._present[regular.Id] = true
	model:SetAttribute("RegularId", regular.Id)
	model:SetAttribute("RegularName", regular.Name)
	model:SetAttribute("BuiltBy", BUILT_BY)
	model.Destroying:Connect(function()
		self._present[regular.Id] = nil
	end)
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			self._present[regular.Id] = nil
		end
	end)

	-- "Take Order" prompt names the regular; the counter speech says who is here
	-- (the card itself is the Take Order button).
	model:GetAttributeChangedSignal("State"):Connect(function()
		if model:GetAttribute("State") ~= "AtCounter" then
			return
		end
		task.defer(function()
			local gui = model:FindFirstChild("OrderBubble")
			local speech = if gui ~= nil then gui:FindFirstChild("Speech") else nil
			if speech ~= nil and speech:IsA("TextLabel") and model:GetAttribute("State") == "AtCounter" then
				speech.Text = `{regular.Name}: Hi, can I order?`
			end
		end)
	end)
	model:GetAttributeChangedSignal("PromptAction"):Connect(function()
		if model:GetAttribute("PromptAction") ~= "Take Order" then
			return
		end
		local prompt = model:FindFirstChild("CustomerPrompt", true)
		if prompt ~= nil and prompt:IsA("ProximityPrompt") then
			prompt.ObjectText = regular.Name
		end
	end)
end

-- At Take Order: the favourite (nil keeps `order`) and the greeting by name. Scripted
-- first-session orders are kept. The greeting is deferred so it lands after SetOrders.
function RegularsService:OrderFor(npc: any, player: Player, _order: any, scripted: boolean): Rules.OrderItem?
	local model: Model = npc.Model
	local id = model:GetAttribute("RegularId")
	local regular = if typeof(id) == "string" then Rules.Get(id) else nil
	if regular == nil then
		return nil
	end
	local favourite = if scripted then nil else Rules.FavouriteOrder(regular, self:_levelOf(player))
	local visits = self._visits[player]
	local met = visits ~= nil and (visits[regular.Id] or 0) > 0
	local line = Rules.Greeting(regular, player.DisplayName, met, favourite ~= nil or scripted, math.random())
	task.defer(function()
		pcall(say, model, line)
	end)
	return favourite
end

---> private

function RegularsService:_isClockedIn(player: Player): boolean
	local ok, result = pcall(function()
		return self._shift:IsClockedIn(player)
	end)
	return ok and result == true
end

function RegularsService:_levelOf(player: Player): number
	local ok, level = pcall(function()
		return Knit.GetService("ProgressionService"):GetLevel(player)
	end)
	return if ok and typeof(level) == "number" then level else 1
end

function RegularsService:_profile(player: Player): any?
	local ok, profile = Knit.GetService("DataService"):GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()
	if ok and typeof(profile) == "table" then
		return profile
	end
	return nil
end

-- Visits from the profile, filling the field for a profile that predates BIG-B5.
function RegularsService:_readVisits(profile: any): { [string]: number }
	local regulars = profile.Regulars
	if typeof(regulars) ~= "table" or typeof(regulars.Visits) ~= "table" then
		profile:SetValue({ "Regulars" }, { Visits = {}, RewardClaimed = false })
		return {}
	end
	return table.clone(regulars.Visits)
end

-- A served regular: one more visit for the barista, first-visit toast, completion reward.
function RegularsService:_stamp(player: Player, id: string)
	local profile = self:_profile(player)
	if profile == nil or player.Parent ~= Players then
		return
	end
	local visits = self:_readVisits(profile)
	local claimed = profile.Regulars.RewardClaimed == true
	local result = Rules.Stamp(visits, id, claimed)
	local regular = Rules.Get(id)
	if result == nil or regular == nil then
		return
	end
	profile:SetValue({ "Regulars", "Visits", id }, result.Visits)
	visits[id] = result.Visits
	self._visits[player] = visits

	local dialog = Knit.GetService("DialogService")
	if result.First then
		local text = `New regular: {regular.Name}! Stamp {result.Stamped}/{#RegularsConfig.ROSTER}`
		dialog:Notify(player, { Title = "Regulars", Description = text, Text = text } :: any)
		pcall(function()
			Knit.GetService("AnalyticsEvents"):Custom(player, "RegularStamped", result.Stamped)
		end)
	end
	if result.Completed then
		profile:SetValue({ "Regulars", "RewardClaimed" }, true)
		Knit.GetService("CurrencyService"):Modify(player, "BobaBucks", RegularsConfig.REWARD_BOBA_BUCKS, "Regulars")
		local titleText = Titles.TextFor(RegularsConfig.REWARD_TITLE)
		pcall(function()
			Knit.GetService("ProgressionService"):GrantTitle(player, RegularsConfig.REWARD_TITLE)
		end)
		local text =
			`Every regular stamped! +{formatThousands(RegularsConfig.REWARD_BOBA_BUCKS)} Boba Bucks and the {titleText} title`
		task.delay(0.5, function()
			pcall(function()
				dialog:Notify(player, { Title = "Regulars", Description = text, Text = text } :: any)
			end)
		end)
	end
	self.Client.BookChanged:Fire(player)
end

---> public

-- The Regulars page model for `player`.
function RegularsService:GetBook(player: Player): { [string]: any }
	local profile = self:_profile(player)
	local visits: { [string]: number } = {}
	local claimed = false
	local loaded = profile ~= nil
	if profile ~= nil then
		local regulars = profile.Regulars
		if typeof(regulars) == "table" then
			if typeof(regulars.Visits) == "table" then
				visits = regulars.Visits
			end
			claimed = regulars.RewardClaimed == true
		end
	end
	local entries = {}
	for index, regular in RegularsConfig.ROSTER do
		local count = visits[regular.Id] or 0
		table.insert(entries, {
			Id = regular.Id,
			Name = regular.Name,
			Favourite = Rules.FavouriteLabel(regular),
			Visits = count,
			Order = index,
		})
	end
	return {
		Loaded = loaded,
		Entries = entries,
		Stamped = Rules.Count(visits),
		Total = #RegularsConfig.ROSTER,
		RewardBobaBucks = RegularsConfig.REWARD_BOBA_BUCKS,
		RewardTitle = Titles.TextFor(RegularsConfig.REWARD_TITLE),
		RewardClaimed = claimed,
	}
end

function RegularsService.Client:GetBook(player: Player)
	return self.Server:GetBook(player)
end

---> lifecycle

function RegularsService:KnitStart()
	self._shift = Knit.GetService("ShiftService")
	local customers = Knit.GetService("CustomerService")
	customers.CustomerLeft:Connect(function(npc: any, reason: string)
		if reason ~= "Served" then
			return
		end
		local id = npc.Model:GetAttribute("RegularId")
		local userId = npc.AssignedUserId
		if typeof(id) ~= "string" or typeof(userId) ~= "number" then
			return
		end
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			return
		end
		task.spawn(function()
			local ok, err = pcall(self._stamp, self, player, id)
			if not ok then
				warnOnce("stamp", `[RegularsService] Stamp failed: {err}`)
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(self.PlayerAdded, self, player)
	end
end

function RegularsService:PlayerAdded(player: Player)
	local profile = self:_profile(player)
	if profile ~= nil and player.Parent == Players then
		self._visits[player] = self:_readVisits(profile)
	end
end

function RegularsService:PlayerRemoving(player: Player)
	self._visits[player] = nil
end

return RegularsService
