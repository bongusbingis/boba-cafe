local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local Pane = require(UI.Components.Pane)
local TopBar = require(script.TopBar)
local BottomLeft = require(script.BottomLeft)
local BottomRight = require(script.BottomRight)
---> private
local c = React.createElement

return function(props: {
    CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil) -> (),
})

    return c(Pane, {
        Native = {
            Size = UDim2.fromScale(1, 1),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
        }
    }, {
        TopBar = c(TopBar, {
            CurrentPage = props.CurrentPage,
            SetCurrentPage = props.SetCurrentPage,
        }),

        BottomLeft = c(BottomLeft, {
            CurrentPage = props.CurrentPage,
            SetCurrentPage = props.SetCurrentPage,
        }),

        BottomRight = c(BottomRight, {
            CurrentPage = props.CurrentPage,
            SetCurrentPage = props.SetCurrentPage,
        }),
    })
end