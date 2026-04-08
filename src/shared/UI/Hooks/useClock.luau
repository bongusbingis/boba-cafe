--!strict
-- This is a binding hook useful for situations where an incremental
-- clock is needed. For example, this can be mapped to TweenService:GetValue()
-- to allow for animations with a fixed start and end, as well as easing styles.

-- The binding value will be incremented by the delta value each time that
-- RunService.PostSimulation is fired.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")

---> dependencies
local React = require(Packages.React)

return function(): React.ReactBinding<number>
	local clockBinding, setClockBinding = React.useBinding(0)

	React.useEffect(function()
		local stepConnection = RunService.PostSimulation:Connect(function(delta)
			setClockBinding(clockBinding:getValue() + delta)
		end)

		return function()
			stepConnection:Disconnect()
		end
	end, {})

	return clockBinding
end
