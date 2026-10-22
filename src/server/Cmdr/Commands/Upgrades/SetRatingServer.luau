--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

local function getService(name: string): any
	local ok, s = pcall(function()
		return Knit.GetService(name)
	end)
	if ok and s then
		return s
	end
	local server = ServerScriptService:FindFirstChild("Server")
	local modules = server and server:FindFirstChild("Modules")
	if modules and modules:FindFirstChild(name) then
		return require(modules[name])
	end
	error("Cannot resolve service: " .. name)
end

return function(_context, rating: number)
	if typeof(rating) ~= "number" then
		return "Error: Rating must be a number."
	end

	local stars = if rating <= 5 then math.clamp(rating, 0, 5) else math.clamp(rating / 20, 0, 5)
	local percentage = if rating <= 5 then math.clamp(rating * 20, 0, 100) else math.clamp(rating, 0, 100)

	local ok, err = pcall(function()
		local CafeRatingService = getService("CafeRatingService")
		CafeRatingService._rating = percentage

		if typeof(CafeRatingService._publish) == "function" then
			CafeRatingService:_publish()
		else
			Workspace:SetAttribute("CafeRating", percentage)
		end

		if percentage >= 100 and typeof(CafeRatingService._checkRush) == "function" then
			CafeRatingService:_checkRush()
		end
	end)

	if not ok then
		return string.format("Failed to set cafe rating: %s", tostring(err))
	end

	return string.format("Cafe rating set to %.1f stars.", stars)
end
