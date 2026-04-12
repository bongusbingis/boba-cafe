---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)

---> config / utilities
local GamepassConfig = require(Shared.Configuration.GamepassConfig)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

---> networking
local ClaimRank = ReplicatedStorage:WaitForChild("Networking"):WaitForChild("ClaimRank")

---> rate-limit: one claim attempt per player per cooldown window
local CLAIM_COOLDOWN_SECONDS = 10
local lastAttempt: { [number]: number } = {}

Players.PlayerRemoving:Connect(function(player: Player)
	lastAttempt[player.UserId] = nil
end)

Knit.OnStart()
	:andThen(function()
		local DialogService = Knit.GetService("DialogService")

		ClaimRank.OnServerInvoke = function(player: Player, passId: any)
			-- Type guard: only accept numeric pass IDs
			if typeof(passId) ~= "number" then
				return { Success = false, Message = "Invalid input." }
			end

			-- Rate limit
			local userId = player.UserId
			local now = os.clock()
			if lastAttempt[userId] and (now - lastAttempt[userId]) < CLAIM_COOLDOWN_SECONDS then
				return { Success = false, Message = "Please wait before claiming again." }
			end
			lastAttempt[userId] = now

			-- Resolve rank from config
			local entry = GamepassConfig[passId]
			if not entry then
				return { Success = false, Message = "That pass does not grant a rank." }
			end

			-- Verify the player actually owns the pass
			local owns = GamepassUtil:PlayerOwnsPassAsync(player, passId)
			if not owns then
				return { Success = false, Message = "You do not own the required game pass." }
			end

			-- TODO: grant entry.RankId to the player via your ranking service
			-- e.g. RankingService:SetRankAsync(player, entry.RankId)

			local message = "Rank claimed successfully!"
			DialogService:Notify(player, { Text = message })
			return { Success = true, Message = message }
		end
	end)
	:catch(warn)
