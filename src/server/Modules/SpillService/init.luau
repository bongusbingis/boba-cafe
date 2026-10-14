local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)
local Config = require(Shared.Configuration.Spills) :: { [string]: any }

local ReplicaService = require(Packages.ReplicaService)
local SpillObject = require(script.Spill)
local TableUtil = require(Packages.TableUtil)
local WorldPath = require(Shared.Utility.WorldPath)

---> constants
local WORLD_WAIT_SECONDS = 10 -- total budget for resolving the authored world/assets in KnitStart
local MAX_CONSECUTIVE_SPAWN_FAILURES = 3
local DEFAULT_SPAWN_INTERVAL_SECONDS = 30

local SpillService = Knit.CreateService({
	Name = "SpillService",
	Client = {
		Trip = Knit.CreateSignal(),
	},
	Spills = {
		Mopping = {},
		Table = {},
		Queue = {},
	},
	Rewards = {},
	Percent = 0,
	--- True only after KnitStart found every authored asset spills need. When false nothing spawns.
	Enabled = false,
	--- workspace.Assets.Spills, resolved in KnitStart (nil when missing).
	SpillsFolder = nil :: Instance?,
	--- ReplicatedStorage.SharedStorage.Spills, resolved in KnitStart (nil when missing).
	Storage = nil :: Instance?,
})

local CleanlinessReplica = ReplicaService.NewReplica({
	ClassToken = ReplicaService.NewClassToken("CleanlinessReplica"),
	Data = { Percent = 0 },
	Replication = "All",
})

local function CountSpills(SpillType): number
	local Count = 0
	for _, RegionSpills in pairs(SpillType) do
		Count += #RegionSpills
	end
	return Count
end

--- Resolves the authored world and assets spills depend on. Each missing path is reported with a warning.
--- Returns true only if everything required is present.
function SpillService:_ResolveWorld(): boolean
	local Deadline = os.clock() + WORLD_WAIT_SECONDS
	local Missing = {}

	local SpillsFolder = WorldPath.waitFor(workspace, { "Assets", "Spills" }, Deadline - os.clock())
	if not SpillsFolder then
		table.insert(Missing, "workspace.Assets.Spills")
	elseif not WorldPath.waitFor(SpillsFolder, { "Areas" }, Deadline - os.clock()) then
		table.insert(Missing, "workspace.Assets.Spills.Areas")
	end

	local Storage = WorldPath.waitFor(ReplicatedStorage, { "SharedStorage", "Spills" }, Deadline - os.clock())
	if not Storage then
		table.insert(Missing, "ReplicatedStorage.SharedStorage.Spills")
	else
		-- Everything a Mopping spill and its cleaning interaction clone or read.
		for _, Path in { { "Spills", "Boba" }, { "Tools", "Mop" }, { "Tools", "MopBucket" }, { "Sparkles" } } do
			if not WorldPath.waitFor(Storage, Path, Deadline - os.clock()) then
				table.insert(Missing, "ReplicatedStorage.SharedStorage.Spills." .. table.concat(Path, "."))
			end
		end
	end

	if #Missing > 0 then
		warn(`[SpillService] Spills disabled; missing authored content: {table.concat(Missing, ", ")}`)
		return false
	end

	-- Spills are parented under Active; create it when the place does not author it.
	if not SpillsFolder:FindFirstChild("Active") then
		local Active = Instance.new("Folder")
		Active.Name = "Active"
		Active.Parent = SpillsFolder
	end

	local Regions = self:_GetRegions(SpillsFolder)
	if #Regions == 0 then
		warn("[SpillService] Spills disabled; workspace.Assets.Spills.Areas has no BasePart children")
		return false
	end

	self.SpillsFolder = SpillsFolder
	self.Storage = Storage
	return true
end

function SpillService:_GetRegions(SpillsFolder: Instance?): { BasePart }
	local Folder = SpillsFolder or self.SpillsFolder
	local Areas = Folder and Folder:FindFirstChild("Areas")
	local Regions = {}
	if Areas then
		for _, Child in Areas:GetChildren() do
			if Child:IsA("BasePart") then
				table.insert(Regions, Child)
			end
		end
	end
	return Regions
end

function SpillService:SpillCleaned(Spill: { Type: string, Region: BasePart })
	if self.Spills[Spill.Type] and self.Spills[Spill.Type][Spill.Region] then
		local RegionSpills = self.Spills[Spill.Type][Spill.Region]
		local Index = table.find(RegionSpills, Spill)
		if Index then
			table.remove(RegionSpills, Index)
		end
	end

	-- Cleanliness saturates at 100. The reward for reaching it (a Cafe Rating boost) is designed separately.
	self.Percent = math.clamp(self.Percent + math.random(1, 2), 0, 100)
	CleanlinessReplica:SetValue({ "Percent" }, self.Percent)

	if self.Enabled and #self.Spills.Queue > 0 then
		local Info = table.remove(self.Spills.Queue, 1)
		local Ok, Err = pcall(self.CreateSpill, self, Info.Type, Info.Object, Info.Region, Info.Bought)
		if not Ok then
			warn(`[SpillService] Failed to create a queued spill: {Err}`)
		end
	end
end

--- Creates a spill, or queues it when the Mopping cap is reached. Returns false if nothing was created.
function SpillService:CreateSpill(Type: string, Object: string, Region: BasePart, Bought: boolean): boolean
	if not self.Enabled then
		return false
	end

	if Type == "Mopping" and CountSpills(self.Spills[Type]) >= Config.MaxTotal then
		table.insert(self.Spills.Queue, { Type = Type, Object = Object, Region = Region, Bought = Bought })
		return true
	end

	-- SpillObject.new cleans up after itself and rethrows if the spill could not be built.
	local Spill = SpillObject.new(Type, Object, Region, Bought)
	if Spill.Destroyed then
		-- No free spot was found in the region; nothing to track.
		return false
	end

	if not self.Spills[Type][Region] then
		self.Spills[Type][Region] = {}
	end

	table.insert(self.Spills[Type][Region], Spill)
	return true
end

function SpillService:CleanEverything()
	for _, SpillType in pairs({ self.Spills.Mopping, self.Spills.Table }) do
		for _, RegionSpills in pairs(SpillType) do
			for _, Spill in pairs(RegionSpills) do
				task.spawn(function()
					if typeof(Spill) == "table" then
						Spill:Clean()
					end
				end)
			end
		end
	end
end

function SpillService:KnitStart()
	Players.PlayerRemoving:Connect(function(Player: Player)
		self.Rewards[Player] = nil
	end)

	-- KnitStart runs on its own thread, so this bounded wait does not hold up other services or clients.
	if not self:_ResolveWorld() then
		return
	end
	self.Enabled = true

	local Failures = 0
	local function TrySpawn(Region: BasePart)
		local Ok, Result = pcall(self.CreateSpill, self, "Mopping", "Boba", Region, false)
		if Ok then
			Failures = 0
			return
		end

		Failures += 1
		warn(`[SpillService] Failed to create a spill ({Failures}/{MAX_CONSECUTIVE_SPAWN_FAILURES}): {Result}`)
		if Failures >= MAX_CONSECUTIVE_SPAWN_FAILURES then
			self.Enabled = false
			warn("[SpillService] Spills disabled after repeated spawn failures; check the spill template.")
		end
	end

	for _, Region in TableUtil.Shuffle(self:_GetRegions()) do
		if not self.Enabled or CountSpills(self.Spills.Mopping) >= Config.MaxSpawned then
			break
		end
		TrySpawn(Region)
	end

	local Interval = if typeof(Config.SpawnInterval) == "number" and Config.SpawnInterval > 0
		then Config.SpawnInterval
		else DEFAULT_SPAWN_INTERVAL_SECONDS

	task.spawn(function()
		while self.Enabled do
			task.wait(Interval)
			local Regions = self:_GetRegions()
			if self.Enabled and #Regions > 0 and CountSpills(self.Spills.Mopping) < Config.MaxSpawned then
				TrySpawn(TableUtil.Random(Regions))
			end
		end
	end)
end

return SpillService
