--[[
    Module: Customer
    Description: One NPC customer — body, movement, dialogue and order state.

    Ported from V4's Customer object, adapted to this codebase: it uses this
    OrderService's order shape, the SharedStorage.NPC asset layout (a single Characters
    folder of HumanoidDescriptions rather than V4's Characters + Special split), and
    drops V4's CameraShaker dependency.

    Owned entirely by CustomerService; nothing else should construct one.
--]]

---> services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local SharedStorage = ReplicatedStorage:WaitForChild("SharedStorage")

local Janitor = require(Packages.Janitor)
local SimplePath = require(Packages.SimplePath)
local GoodSignal = require(Packages.GoodSignal)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)

---> assets
local NPCStorage = SharedStorage:WaitForChild("NPC")
local RIG = NPCStorage:WaitForChild("Rig")
local CHARACTERS = NPCStorage:WaitForChild("Characters")
local OVERHEAD = NPCStorage:FindFirstChild("Overhead")

--- Live customers must be parented into Workspace. SharedStorage.NPC.InUse lives in
--- ReplicatedStorage, so parenting there left every customer invisible and unable to
--- path — they existed, but no player could ever see or serve one.
local LIVE_FOLDER_NAME = "Customers"

local function getLiveFolder(): Instance
	local existing = workspace:FindFirstChild(LIVE_FOLDER_NAME)
	if existing then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = LIVE_FOLDER_NAME
	folder.Parent = workspace

	return folder
end

---> constants
local PATH_RETRY_LIMIT = 5
local PATH_AGENT = {
	WaypointSpacing = 6,
	Costs = { Water = math.huge, Danger = math.huge },
}

---> module declaration
local Customer = {}
Customer.__index = Customer

export type CustomerImpl = typeof(setmetatable({} :: any, Customer))

---> private

local function pickDescription(personality: string): HumanoidDescription?
	local options = {}

	for _, child in CHARACTERS:GetChildren() do
		if not child:IsA("HumanoidDescription") then
			continue
		end

		-- Karen descriptions are reserved for Karen customers, and vice versa.
		local isKaren = child.Name:lower():find("karen") ~= nil
		if (personality == "Karen") == isKaren then
			table.insert(options, child)
		end
	end

	if #options == 0 then
		return nil
	end

	return options[math.random(1, #options)]
end

---> constructor

--[=[
	Creates a customer at `spawnCFrame` that will walk to `register`.
	`onOrderReady` is called with the customer once it has decided what it wants.
]=]
function Customer.new(register: Instance, spawnCFrame: CFrame)
	local self = setmetatable({}, Customer)

	self.Id = HttpService:GenerateGUID(false)
	self.Register = register
	self.Personality = if math.random() < CustomerConfig.KarenChance then "Karen" else "Default"
	self.Attempts = 0
	self.Order = nil
	self.OrderNumber = nil
	self.Active = true
	self.ArrivedAt = nil

	self.Janitor = Janitor.new()
	self.Left = GoodSignal.new()
	-- GoodSignal has no Destroy, only DisconnectAll — naming a method it does not have
	-- throws inside Janitor:Add and aborts the whole constructor.
	self.Janitor:Add(self.Left, "DisconnectAll")

	if not self:_buildCharacter(spawnCFrame) then
		self:Destroy()
		return nil
	end

	self:_setupPath()

	return self
end

---> private methods

function Customer:_buildCharacter(spawnCFrame: CFrame): boolean
	local character = RIG:Clone()
	character.Name = `Customer_{self.Id}`

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		warn("[Customer] Rig has no Humanoid.")
		character:Destroy()
		return false
	end

	-- Appearance is cosmetic: a failed description must not abort the spawn.
	local description = pickDescription(self.Personality)
	if description then
		pcall(function()
			humanoid:ApplyDescription(description)
		end)
		self.DisplayName = description.Name
	end

	character:PivotTo(spawnCFrame)
	character.Parent = getLiveFolder()

	self.Character = character
	self.Humanoid = humanoid
	self.Janitor:Add(character, "Destroy")

	self:_buildOverhead()

	return true
end

function Customer:_buildOverhead()
	if not OVERHEAD then
		return
	end

	local head = self.Character:FindFirstChild("Head")
	if not head then
		return
	end

	local overhead = OVERHEAD:Clone()
	overhead.Parent = head
	overhead.Adornee = head

	local label = overhead:FindFirstChild("Username")
	if label and label:IsA("TextLabel") then
		label.Text = self.DisplayName or "Customer"
	end
end

function Customer:_setupPath()
	self.Path = {
		Retries = 0,
		Goal = nil,
		Callback = nil,
		Runner = SimplePath.new(self.Character, PATH_AGENT),
	}

	self.Janitor:Add(self.Path.Runner.Blocked:Connect(function()
		if self.Path.Goal then
			self.Path.Runner:Run(self.Path.Goal)
		end
	end))

	self.Janitor:Add(self.Path.Runner.Reached:Connect(function()
		self.Path.Goal = nil
		self.Path.Retries = 0

		local callback = self.Path.Callback
		self.Path.Callback = nil
		if callback then
			callback()
		end
	end))

	self.Janitor:Add(self.Path.Runner.Error:Connect(function()
		if not self.Path.Goal then
			return
		end

		if self.Path.Retries < PATH_RETRY_LIMIT then
			self.Path.Retries += 1
			self.Path.Runner:Run(self.Path.Goal)
			return
		end

		-- Pathing has failed repeatedly (blocked doorway, bad geometry). Teleport to
		-- the goal rather than leaving the customer stuck in the middle of the cafe.
		local goal = self.Path.Goal
		local position = if typeof(goal) == "Instance" and goal:IsA("BasePart")
			then goal.Position
			else goal

		if typeof(position) == "Vector3" then
			self.Character:PivotTo(CFrame.new(position))
		end

		self.Path.Goal = nil
		self.Path.Retries = 0

		local callback = self.Path.Callback
		self.Path.Callback = nil
		if callback then
			callback()
		end
	end))
end

---> public

--- Walks to a destination, calling `callback` on arrival (or on giving up).
function Customer:MoveTo(destination: Vector3 | CFrame | BasePart, callback: (() -> ())?)
	if not self.Active or not self.Character then
		return
	end

	local goal = destination
	if typeof(destination) == "CFrame" then
		goal = destination.Position
	end

	self.Path.Goal = goal
	self.Path.Callback = callback
	self.Path.Retries = 0
	self.Path.Runner:Run(goal)
end

--- Says a line from a dialogue category. Returns the line so callers can log it.
function Customer:Speak(category: string, ...): string?
	local line = CustomerConfig.getLine(category, self.Personality)
	if not line or not self.Character then
		return nil
	end

	local formatted = if select("#", ...) > 0 then string.format(line, ...) else line

	local head = self.Character:FindFirstChild("Head")
	if head then
		-- Bubble chat renders this without needing a custom GUI.
		local chatEvent = game:GetService("Chat")
		pcall(function()
			chatEvent:Chat(head, formatted)
		end)
	end

	return formatted
end

--- Marks this customer as waiting for a Worker to take their order at the register, and
--- publishes that on the character so clients can offer it in the "Select Customer" list.
--- Attributes rather than a remote: they replicate on their own and the client already has
--- the character.
function Customer:SetAwaitingWorker(customerId: number, awaiting: boolean)
	self.AwaitingWorker = awaiting

	if not self.Character then
		return
	end

	self.Character:SetAttribute("CustomerId", customerId)
	self.Character:SetAttribute("AwaitingOrder", awaiting)
	self.Character:SetAttribute("CustomerName", self.DisplayName or "Customer")
end

--- Repeats what they want. A Worker who walked away, or who missed the first line,
--- otherwise has no way to find out what to type into the register.
function Customer:RepeatOrder()
	if not self.Order or #self.Order == 0 then
		return
	end

	local first = self.Order[1]
	local name = if typeof(first) == "table" then (first.ItemName or first.Name) else tostring(first)

	self:Speak("Greeting", name or "drink")
end

--- Records the order this customer wants and greets the room.
function Customer:AssignOrder(orderItems: { any }, orderNumber: string?)
	self.Order = orderItems
	self.OrderNumber = orderNumber
	self.ArrivedAt = os.time()

	local first = orderItems[1]
	local name = if typeof(first) == "table" then (first.ItemName or first.Name) else tostring(first)

	self:Speak("Greeting", name or "drink")

	-- Additional items are called out one at a time, as V4 did.
	for index = 2, #orderItems do
		local item = orderItems[index]
		local itemName = if typeof(item) == "table" then (item.ItemName or item.Name) else tostring(item)
		task.delay(index * 1.5, function()
			if self.Active then
				self:Speak("Followup", itemName or "drink")
			end
		end)
	end
end

--- Checks a delivered set of tools against the order.
--- Returns true when correct; otherwise consumes an attempt and complains.
function Customer:CheckOrder(deliveredNames: { string }): boolean
	if not self.Order then
		return false
	end

	local wanted: { [string]: number } = {}
	for _, item in self.Order do
		local name = if typeof(item) == "table" then (item.ItemName or item.Name) else tostring(item)
		if name then
			wanted[name] = (wanted[name] or 0) + 1
		end
	end

	for _, name in deliveredNames do
		if wanted[name] then
			wanted[name] -= 1
			if wanted[name] <= 0 then
				wanted[name] = nil
			end
		end
	end

	if next(wanted) == nil then
		self:Speak("WorkerAction")
		return true
	end

	self.Attempts += 1
	self:Speak("WrongOrder")

	if self.Attempts >= CustomerConfig.MaxAttempts then
		self:Leave()
	end

	return false
end

--- Whether the customer has been waiting past its patience.
function Customer:HasRunOutOfPatience(): boolean
	if not self.ArrivedAt then
		return false
	end

	return (os.time() - self.ArrivedAt) >= CustomerConfig.PatienceSeconds
end

--- Says goodbye, walks off and destroys itself.
function Customer:Leave()
	if not self.Active then
		return
	end

	self.Active = false
	self:Speak("Leaving")
	self.Left:Fire(self)

	-- Give the farewell a moment to show before the body disappears.
	task.delay(2, function()
		self:Destroy()
	end)
end

function Customer:Destroy()
	self.Active = false

	if self.Path and self.Path.Runner then
		pcall(function()
			self.Path.Runner:Destroy()
		end)
	end

	if self.Janitor then
		self.Janitor:Destroy()
		self.Janitor = nil
	end

	self.Character = nil
end

return Customer
