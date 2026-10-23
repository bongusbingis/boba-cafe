--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RankUtil = require(Shared.Utility.RankUtil)

return function(_context: any)
	local lines = { "=== In-Game Staff Members ===" }
	local count = 0

	for _, player in Players:GetPlayers() do
		local rankData = RankUtil:GetRankAndRoleAsync(player)
		local rank = rankData.Rank
		local role = rankData.Role or "Unknown"

		local isStaff = rank >= 11 or player:GetAttribute("IsAdmin") == true
		if RunService:IsStudio() then
			isStaff = true
		end

		if isStaff then
			count += 1
			table.insert(
				lines,
				string.format("• %s (@%s) — %s (Rank %d)", player.DisplayName, player.Name, role, rank)
			)
		end
	end

	if count == 0 then
		return "No staff members currently in this server."
	end

	table.insert(lines, string.format("Total: %d staff member(s) online.", count))
	return table.concat(lines, "\n")
end
