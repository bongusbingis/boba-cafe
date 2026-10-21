--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local QuestCard = require(UI.Components.Core.Hud.QuestCard)

local c = React.createElement

-- Quests tab of the Menu: the daily and weekly lists, claim and reroll.
return function()
	return c(QuestCard, { Embedded = true })
end
