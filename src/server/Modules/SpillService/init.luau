local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)
local Config = require(Shared.Configuration.Spills) :: { [string]: any }

local SpillsFolder = workspace.Assets.Spills

local ReplicaService = require(Packages.ReplicaService)
local SpillObject = require(script.Spill)
local TableUtil = require(Packages.TableUtil)
local CurrencyService

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
	BoostActive = false,
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

function SpillService:SpillCleaned(Spill: { Type: string, Region: BasePart })
	if self.Spills[Spill.Type] and self.Spills[Spill.Type][Spill.Region] then
		local RegionSpills = self.Spills[Spill.Type][Spill.Region]
		local Index = table.find(RegionSpills, Spill)
		if Index then
			table.remove(RegionSpills, Index)
		end
	end

	if self.BoostActive then
		return
	end

	self.Percent = math.clamp(self.Percent + math.random(1, 2), 0, 100)
	CleanlinessReplica:SetValue({ "Percent" }, self.Percent)

	if self.Percent >= 100 then
		CurrencyService.GlobalMulti.Amount = Config.BoostMultiplier
		CurrencyService.GlobalMulti.Duration = os.time() + Config.BoostDuration

		self.BoostActive = true
		task.delay(Config.BoostDuration, function()
			self.Percent = 0
			CleanlinessReplica:SetValue({ "Percent" }, self.Percent)
			CurrencyService.GlobalMulti.Duration = 0
			CurrencyService.GlobalMulti.Amount = 0
			self.BoostActive = false
		end)
	end

	if #self.Spills.Queue > 0 then
		local Info = table.remove(self.Spills.Queue, 1)
		self:CreateSpill(Info.Type, Info.Object, Info.Region, Info.Bought)
	end
end

function SpillService:CreateSpill(Type: string, Object: string, Region: BasePart, Bought: boolean)
	if Type == "Mopping" and CountSpills(self.Spills[Type]) >= Config.MaxTotal then
		table.insert(self.Spills.Queue, { Type = Type, Object = Object, Region = Region, Bought = Bought })
		return
	end

	local Spill = SpillObject.new(Type, Object, Region, Bought)

	if not self.Spills[Type][Region] then
		self.Spills[Type][Region] = {}
	end

	table.insert(self.Spills[Type][Region], Spill)
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
	CurrencyService = Knit.GetService("CurrencyService")
	task.wait()

	task.spawn(function()
		while true do
			task.wait(Config.SpawnInterval)
			if CountSpills(self.Spills.Mopping) < Config.MaxSpawned then
				self:CreateSpill("Mopping", "Boba", TableUtil.Random(SpillsFolder.Areas:GetChildren()), false)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(Player: Player)
		self.Rewards[Player] = nil
	end)

	for _, Region in pairs(TableUtil.Shuffle(SpillsFolder.Areas:GetChildren())) do
		if CountSpills(self.Spills.Mopping) >= Config.MaxSpawned then
			break
		end

		self:CreateSpill("Mopping", "Boba", Region, false)
	end
end

return SpillService