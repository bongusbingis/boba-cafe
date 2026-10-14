--[[
    Author: bongusbingis
    Module: Teams.server.luau
    Created: 05/31/2025

    Creates the teams in TeamsConfig and keeps each player's team in sync with
    the `ClockedIn` attribute that ShiftService owns.
--]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeamsService = game:GetService("Teams")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TeamConfig = require(Shared.Configuration.TeamsConfig)

---> constants
local CLOCKED_IN_ATTRIBUTE = "ClockedIn"

---> private
local teamsByClockedIn: { [boolean]: Team } = {}
local connections: { [Player]: RBXScriptConnection } = {}

local function createTeams()
	for _, team in TeamConfig do
		local teamInstance = TeamsService:FindFirstChild(team.Name) :: Team?
		if not teamInstance then
			local newTeam = Instance.new("Team")
			newTeam.Name = team.Name
			newTeam.TeamColor = team.Color
			newTeam.AutoAssignable = team.AutoAssignable == true
			newTeam.Parent = TeamsService
			teamInstance = newTeam
		end
		teamsByClockedIn[team.ClockedIn == true] = teamInstance :: Team
	end
end

local function applyTeam(player: Player)
	local clockedIn = player:GetAttribute(CLOCKED_IN_ATTRIBUTE)
	if typeof(clockedIn) ~= "boolean" then
		return -- ShiftService has not set it yet; keep the auto-assigned team
	end

	local team = teamsByClockedIn[clockedIn]
	if team and player.Team ~= team then
		player.Team = team
	end
end

local function handlePlayer(player: Player)
	if connections[player] then
		return
	end
	connections[player] = player:GetAttributeChangedSignal(CLOCKED_IN_ATTRIBUTE):Connect(function()
		applyTeam(player)
	end)
	applyTeam(player)
end

---> init

createTeams()

for _, player in Players:GetPlayers() do
	task.spawn(handlePlayer, player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(handlePlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	local connection = connections[player]
	if connection then
		connection:Disconnect()
		connections[player] = nil
	end
end)
