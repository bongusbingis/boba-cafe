local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

--- Returns an ever-increasing time value (seconds) that updates every frame.
--- Components that call this will re-render each frame while mounted.
return function(): number
	local time, setTime = React.useState(os.clock())

	React.useEffect(function()
		local conn = RunService.Heartbeat:Connect(function()
			setTime(os.clock())
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	return time
end
