--[[
    Module: OrderController
    Description: Knit controller that listens to OrderService server signals and
                 maintains client-side order state. React components subscribe to
                 the exposed GoodSignals rather than talking to the service directly.
--]]

---> Services

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

---> Dependencies

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)
local UiSfx = require(ReplicatedStorage:WaitForChild("Shared").UI.Utility.UiSfx)
local Styles = require(ReplicatedStorage:WaitForChild("Shared").UI.Styles)
local WorldPath = require(ReplicatedStorage:WaitForChild("Shared").Utility.WorldPath)

---> Controller

local OrderController = Knit.CreateController({
	Name = "OrderController",
})

local LocalPlayer = Players.LocalPlayer

local PlayerBeams = {}
local DepositWatchers: { [Instance]: RBXScriptConnection } = {} -- node -> owner watcher while its deposit prompt is on

-- Direct-handoff beam: points the preparing barista at their ordering customer
-- while the server reports them in direct range. It never reads the
-- station-hints setting, so it shows even with hints disabled.
local HANDOFF_BEAM_NAME = "RealOrderHandoffBeam"
local HANDOFF_BEAM_WIDTH = 0.35
local HANDOFF_BEAM_TRANSPARENCY = 0.35
local HANDOFF_BEAM_POLL_SECONDS = 0.25

local HandoffTargetUserId: number? = nil
local HandoffBeam: Beam? = nil
local HandoffAttachments: { Attachment } = {}

local function characterRoot(character: Model?): BasePart?
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function clearHandoffBeam()
	local beam = HandoffBeam
	if beam then
		beam.Enabled = false
		beam.Attachment0 = nil
		beam.Attachment1 = nil
	end
	for _, attachment in HandoffAttachments do
		attachment:Destroy()
	end
	table.clear(HandoffAttachments)
end

-- Re-resolves both ends every poll so respawns and deaths re-hook
-- automatically; a missing end only hides the beam until it is back.
local function updateHandoffBeam()
	local customer = if HandoffTargetUserId ~= nil then Players:GetPlayerByUserId(HandoffTargetUserId) else nil
	local myRoot = characterRoot(LocalPlayer.Character)
	local theirRoot = if customer ~= nil then characterRoot(customer.Character) else nil
	if myRoot == nil or theirRoot == nil then
		clearHandoffBeam()
		return
	end
	local beam = HandoffBeam
	if beam == nil or beam.Parent == nil then
		clearHandoffBeam()
		beam = Instance.new("Beam")
		beam.Name = HANDOFF_BEAM_NAME
		beam.Color = ColorSequence.new(Styles.GOLD)
		beam.Width0 = HANDOFF_BEAM_WIDTH
		beam.Width1 = HANDOFF_BEAM_WIDTH
		beam.Transparency = NumberSequence.new(HANDOFF_BEAM_TRANSPARENCY)
		beam.FaceCamera = true
		beam.LightEmission = 0.5
		beam.Segments = 20
		beam.Parent = workspace
		HandoffBeam = beam
	end
	local from = HandoffAttachments[1]
	if from == nil or from.Parent ~= myRoot then
		if from ~= nil then
			from:Destroy()
		end
		from = Instance.new("Attachment")
		from.Parent = myRoot
		HandoffAttachments[1] = from
	end
	local to = HandoffAttachments[2]
	if to == nil or to.Parent ~= theirRoot then
		if to ~= nil then
			to:Destroy()
		end
		to = Instance.new("Attachment")
		to.Parent = theirRoot
		HandoffAttachments[2] = to
	end
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Enabled = true
end

-- The active ticket (slot 1). NPC and real-player orders are both tickets from
-- CustomerService (a real one has Real = true); kitchen guidance reads this.
OrderController.CurrentOrder = nil :: { [string]: any }?
OrderController.Ticket = nil :: { [string]: any }? -- same as CurrentOrder
OrderController.Tickets = {} :: { { [string]: any } } -- up to 2 tickets, ordered by Slot
OrderController._ticketsById = {} :: { [string]: { [string]: any } }
OrderController.ReadyNode = nil :: Instance?
OrderController.ActiveNpcOrder = nil :: { [string]: any }?

OrderController.OrderChanged = GoodSignal.new()
OrderController.TicketsChanged = GoodSignal.new() -- fires(tickets: { ticket })
OrderController.ReadyNodeChanged = GoodSignal.new()
OrderController.AnnouncementReceived = GoodSignal.new()
OrderController.OpenOrderingRequested = GoodSignal.new() -- fires(npcOrderData: any)
OrderController.CloseOrderingRequested = GoodSignal.new() -- fires()

---> Private

-- ReplicatedStorage.SharedStorage.Effects.PickupBeam is authored in the place. It
-- is looked up on use; when missing, the pick-up beam is skipped (warned once).
local warnedMissingBeam = false
local function getPickupBeam(): Beam?
	local beam = WorldPath.find(ReplicatedStorage, { "SharedStorage", "Effects", "PickupBeam" })
	if beam and beam:IsA("Beam") then
		return beam
	end
	if not warnedMissingBeam then
		warnedMissingBeam = true
		warn("[OrderController] SharedStorage.Effects.PickupBeam not found; pick-up beam disabled.")
	end
	return nil
end

-- DEC-059: the counter Take Order prompt on a real customer. The server keeps it
-- Enabled; this client shows it only to clocked-in baristas other than the customer,
-- and only to the lock holder while a barista is taking the order. Presentation only.
local COUNTER_PROMPT_TAG = "CounterOrderPrompt"

local function refreshCounterPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local customerId = prompt:GetAttribute("CustomerUserId")
	local takerId = prompt:GetAttribute("TakerUserId")
	prompt.Enabled = customerId ~= LocalPlayer.UserId
		and LocalPlayer:GetAttribute("ClockedIn") == true
		and (takerId == nil or takerId == 0 or takerId == LocalPlayer.UserId)
end

-- Real-order handoff prompts ride the ordering customer's own root part. The
-- customer can never trigger their own handoff (the server requires the
-- preparing barista), so hide it on their own screen. Presentation only.
local HANDOFF_PROMPT_NAME = "RealOrderHandoff"

local function hideOwnHandoffPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	prompt.Enabled = false
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if (prompt :: ProximityPrompt).Enabled then
			(prompt :: ProximityPrompt).Enabled = false
		end
	end)
end

local function watchOwnHandoffPrompts(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant.Name == HANDOFF_PROMPT_NAME then
			hideOwnHandoffPrompt(descendant)
		end
	end
	character.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == HANDOFF_PROMPT_NAME then
			hideOwnHandoffPrompt(descendant)
		end
	end)
end

local function watchCounterPrompts()
	local function onAdded(prompt: Instance)
		refreshCounterPrompt(prompt)
		prompt.AttributeChanged:Connect(function()
			refreshCounterPrompt(prompt)
		end)
	end
	CollectionService:GetInstanceAddedSignal(COUNTER_PROMPT_TAG):Connect(onAdded)
	for _, prompt in CollectionService:GetTagged(COUNTER_PROMPT_TAG) do
		onAdded(prompt)
	end
	LocalPlayer:GetAttributeChangedSignal("ClockedIn"):Connect(function()
		for _, prompt in CollectionService:GetTagged(COUNTER_PROMPT_TAG) do
			refreshCounterPrompt(prompt)
		end
	end)
end

---> Lifecycle
function OrderController:KnitStart()
	local OrderService = Knit.GetService("OrderService")

	watchCounterPrompts()
	if LocalPlayer.Character then
		watchOwnHandoffPrompts(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(watchOwnHandoffPrompts)

	Knit.GetService("CustomerService").TicketChanged:Connect(function(ticket, slot)
		local byId = self._ticketsById
		if ticket ~= nil then
			-- A new ticket replaces whatever held its slot (or its own Id).
			for id, held in byId do
				if id == ticket.Id or held.Slot == (ticket.Slot or slot) then
					byId[id] = nil
				end
			end
			byId[ticket.Id] = ticket
		else
			for id, held in byId do
				if held.Slot == slot then
					byId[id] = nil
				end
			end
		end
		local list = {}
		for _, held in byId do
			table.insert(list, held)
		end
		table.sort(list, function(a, b)
			return (a.Slot or 1) < (b.Slot or 1)
		end)
		while #list > 2 do
			byId[list[#list].Id] = nil
			table.remove(list)
		end
		self.Tickets = list
		self.TicketsChanged:Fire(list)

		self.Ticket = list[1]
		self.CurrentOrder = self.Ticket
		self.OrderChanged:Fire(self.Ticket)
	end)

	OrderService.PickUpNodeVisibilityChanged:Connect(function(node, isVisible: boolean, isReady: boolean?)
		-- OrderOwner is the node's server-set owner: a node that is already filled never
		-- offers a deposit (the pick-up prompt for its owner is shown with isReady).
		local previousWatcher = DepositWatchers[node]
		if previousWatcher then
			previousWatcher:Disconnect()
			DepositWatchers[node] = nil
		end
		local ownerValue = node:FindFirstChild("OrderOwner")
		if isVisible and not isReady and ownerValue and ownerValue:IsA("IntValue") then
			if ownerValue.Value ~= 0 then
				isVisible = false
			else
				-- Another barista may fill the node while this prompt is showing.
				DepositWatchers[node] = ownerValue:GetPropertyChangedSignal("Value"):Connect(function()
					if ownerValue.Value ~= 0 then
						node.ProximityPrompt.Enabled = false
					end
				end)
			end
		end
		node.ProximityPrompt.Enabled = isVisible
		if #PlayerBeams ~= 0 and isVisible == false then
			for num, beam in PlayerBeams do
				if beam.Attachment1.Parent == node then
					table.remove(PlayerBeams, num)
					beam.Attachment0:Destroy()
					beam.Attachment1:Destroy()
					beam:Destroy()
				end
			end
		end
		local character = LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local pickupBeam = isReady and rootPart and getPickupBeam()
		if pickupBeam then
			local beam = pickupBeam:Clone()
			table.insert(PlayerBeams, beam)
			beam.Parent = rootPart

			local a0 = Instance.new("Attachment")
			local a1 = Instance.new("Attachment")
			a0.Parent = rootPart
			a1.Parent = node

			beam.Attachment0 = a0
			beam.Attachment1 = a1
		end
	end)

	OrderService.Announcement:Connect(function(title: string, body: string, color: Color3)
		self.AnnouncementReceived:Fire(title, body, color)
	end)

	-- Direct-handoff target from the server (nil clears). Re-checked on a poll
	-- so character respawns re-hook without extra wiring.
	OrderService.HandoffTargetChanged:Connect(function(customerId: number?)
		HandoffTargetUserId = customerId
		updateHandoffBeam()
	end)
	task.spawn(function()
		while true do
			task.wait(HANDOFF_BEAM_POLL_SECONDS)
			local ok, err = pcall(updateHandoffBeam)
			if not ok then
				warn("[OrderController] Handoff beam update failed:", err)
			end
		end
	end)

	-- Serve chime (SOUNDS D5): the serve toast is the client signal; pitch rises with combo.
	Knit.GetService("DialogService").NotificationSignal:Connect(function(n)
		if typeof(n) ~= "table" then
			return
		end
		local text = if typeof(n.Text) == "string" and n.Text ~= ""
			then n.Text
			else (n.Title or "") .. " " .. (n.Description or "")
		if string.sub(text, 1, 13) ~= "Order served!" then
			return
		end
		local comboN = tonumber(string.match(text, "Combo ×(%d+)"))
		UiSfx.Play("Serve", { Speed = UiSfx.ServeSpeed(comboN) })
	end)

	local customerService = Knit.GetService("CustomerService")
	if customerService.OpenOrderingTablet ~= nil then
		customerService.OpenOrderingTablet:Connect(function(data)
			self:OpenOrdering(data)
		end)
	end
	if customerService.CloseOrderingTablet ~= nil then
		customerService.CloseOrderingTablet:Connect(function()
			self:CloseOrdering()
		end)
	end
end

function OrderController:OpenOrdering(data: any)
	self.ActiveNpcOrder = data
	self.OpenOrderingRequested:Fire(data)
end

function OrderController:CloseOrdering()
	self.ActiveNpcOrder = nil
	self.CloseOrderingRequested:Fire()
end

return OrderController
