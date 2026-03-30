--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local App = require(Shared.UI.App)

---> private
local c = React.createElement

return function(target)
	local root = ReactRoblox.createRoot(target)
    
	root:render(c(App))

	return function()
		root:unmount()
	end
end
