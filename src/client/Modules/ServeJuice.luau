--!strict
-- REVIVAL-001 SERVE-PAYPOPUP (S3): animates the server's ServePay billboard
-- locally (rise 2 studs, fade out over 1 s). Purely cosmetic; every callback
-- is pcall-wrapped so an error here never reaches gameplay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

local RISE_STUDS = 2
local FADE_SECONDS = 1

local ServeJuice = Knit.CreateController({
	Name = "ServeJuice",
})

local function onAdded(instance: Instance)
	if not (instance:IsA("BillboardGui") and instance.Name == "ServePay") then
		return
	end
	if instance:GetAttribute("Juiced") == true then
		return
	end
	instance:SetAttribute("Juiced", true)

	local info = TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(instance, info, { StudsOffset = instance.StudsOffset + Vector3.new(0, RISE_STUDS, 0) }):Play()

	local label = instance:FindFirstChildWhichIsA("TextLabel")
	if label ~= nil then
		TweenService:Create(label, info, { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildWhichIsA("UIStroke")
		if stroke ~= nil then
			TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		end
	end
end

function ServeJuice:KnitInit() end

function ServeJuice:KnitStart()
	task.spawn(function()
		local customers = workspace:WaitForChild("Customers", 30)
		if customers == nil then
			warn("[ServeJuice] workspace.Customers not found; pay popup disabled")
			return
		end
		customers.DescendantAdded:Connect(function(instance)
			pcall(onAdded, instance)
		end)
	end)
end

return ServeJuice
