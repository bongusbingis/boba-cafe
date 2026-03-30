local AppEntry = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local App = require(Shared.UI.App)

---> render app component
local uiHandle = Instance.new("ScreenGui")
uiHandle.ResetOnSpawn = false
uiHandle.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
uiHandle.Parent = Players.LocalPlayer.PlayerGui

local root = ReactRoblox.createRoot(uiHandle)

function AppEntry:Start()
    root:render(React.createElement(App))
end

return AppEntry