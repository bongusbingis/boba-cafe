--[[
    Author: bongusbingis
    Module: Teams.server.luau
    Created: 05/31/2025
--]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeamsService = game:GetService("Teams")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TeamConfig = require(Shared.Configuration.TeamsConfig)
local RankUtil = require(Shared.Utility.RankUtil)

---> private

local function createTeams()
    for _, team in TeamConfig do
        local teamInstance = Instance.new("Team")
        teamInstance.Name = team.Name
        teamInstance.TeamColor = team.Color
        teamInstance.AutoAssignable = team.AutoAssignable == true
        teamInstance.Parent = TeamsService
    end
end

local function handlePlayer(player: Player)
    local playerRank = RankUtil:GetRankAsync(player)
    local currentTeamRank = 0
    local currentTeam

    for _, team in TeamConfig do
        if not team.Rank then
            continue
        end

        if team.Rank >= currentTeamRank and playerRank >= team.Rank then
            currentTeamRank = team.Rank
            currentTeam = TeamsService:FindFirstChild(team.Name)
        end
    end

    if not currentTeam then
        return
    end

    player.Team = currentTeam
end

---> init

createTeams()

for _, player in Players:GetPlayers() do
    task.spawn(handlePlayer, player)
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(handlePlayer, player)
end)
