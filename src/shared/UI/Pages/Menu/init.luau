local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local OpenableMenu = require(UI.Components.Core.OpenableMenu)

---> pages
local FoodMenu    = require(script.FoodMenu)
local Daily       = require(script.Daily)
local PromoCodes  = require(script.PromoCodes)
local Credits     = require(script.Credits)
local Purchases   = require(script.Purchases)
local ServerInfo  = require(script.ServerInfo)
local Settings    = require(script.Settings)
local Statistics  = require(script.Statistics)
local c = React.createElement

return function()
    return c(OpenableMenu, {
        TitleText = "Menu",
        TitleColor = Styles.GREEN,
        Pages = {
            {
                Key = "FoodMenu",
                Label = "Food Menu",
                LayoutOrder = 1,
                Content = {
                    Page = c(FoodMenu, {}),
                },
            },
            {
                Key = "Daily",
                Label = "Daily Rewards",
                LayoutOrder = 2,
                Content = {
                    Page = c(Daily, {}),
                },
            },
            {
                Key = "PromoCodes",
                Label = "Promo Codes",
                LayoutOrder = 3,
                Content = {
                    Page = c(PromoCodes, {}),
                },
            },
            {
                Key = "Statistics",
                Label = "Statistics",
                LayoutOrder = 4,
                Content = {
                    Page = c(Statistics, {}),
                },
            },
            {
                Key = "Purchases",
                Label = "Purchases",
                LayoutOrder = 5,
                Content = {
                    Page = c(Purchases, {}),
                },
            },
            {
                Key = "ServerInfo",
                Label = "Server Info",
                LayoutOrder = 6,
                Content = {
                    Page = c(ServerInfo, {}),
                },
            },
            {
                Key = "Settings",
                Label = "Settings",
                LayoutOrder = 7,
                Content = {
                    Page = c(Settings, {}),
                },
            },
            {
                Key = "Credits",
                Label = "Credits",
                LayoutOrder = 8,
                Content = {
                    Page = c(Credits, {}),
                },
            },
        },
    })
end
