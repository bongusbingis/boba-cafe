---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local App = require(Shared.UI.App)

---> controller declaration
local AppEntry = Knit.CreateController {
	Name = "AppEntry",
}

function AppEntry:KnitStart()
	local uiHandle = Instance.new("ScreenGui")
	uiHandle.ResetOnSpawn = false
	uiHandle.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	uiHandle.IgnoreGuiInset = true
	uiHandle.Parent = Players.LocalPlayer.PlayerGui
	
	xpcall(function()
		local root = ReactRoblox.createRoot(uiHandle)
		root:render(React.createElement(App))
	end, function()
		warn("Render failure")
	end)
	
end

return AppEntry
