-- selene: allow(undefined_variable)
--[[
	SocialInviteService.spec.luau
	Unit tests for SocialInviteService.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Promise = require(ReplicatedStorage.Packages.Promise)
	local service = require(ServerScriptService.Server.Modules.SocialInviteService)

	-- Friendships the fake IsFriendsWith reports, as friendships["a:b"] = true (either order).
	local friendships: { [string]: boolean } = {}
	local friendsCallErrors = false

	local function befriend(a: number, b: number)
		friendships[`{a}:{b}`] = true
		friendships[`{b}:{a}`] = true
	end

	local function makePlayer(userId: number, followUserId: number?, joinData: any?, accountAge: number?)
		return {
			UserId = userId,
			Name = "Player_" .. userId,
			FollowUserId = followUserId,
			AccountAge = accountAge or 30,
			GetJoinData = function(_)
				return joinData or {}
			end,
			IsFriendsWith = function(self, otherUserId: number)
				if friendsCallErrors then
					error("HTTP 500")
				end
				return friendships[`{self.UserId}:{otherUserId}`] == true
			end,
		}
	end

	local function makeProfile(initialInvited: { [string]: boolean }?)
		local data = {
			InviteRewardedBy = 0,
			InviteRewardsToday = { Day = 0, Count = 0 },
			InvitedFriends = initialInvited or {},
			Currency = {
				BobaBucks = 0,
				Points = 0,
			},
		}
		local proxy = {
			Data = data,
			InvitedFriends = data.InvitedFriends,
			SetValueCalls = {} :: { { path: { string }, value: any } },
		}
		function proxy:SetValue(path: { string }, value: any)
			table.insert(self.SetValueCalls, { path = path, value = value })
			if #path == 1 then
				self.Data[path[1]] = value
				self[path[1]] = value
			elseif #path == 2 then
				if typeof(self.Data[path[1]]) ~= "table" then
					self.Data[path[1]] = {}
				end
				self.Data[path[1]][path[2]] = value
				if typeof(self[path[1]]) ~= "table" then
					self[path[1]] = {}
				end
				self[path[1]][path[2]] = value
			end
		end
		return proxy
	end

	local playersByUserId: { [number]: any }
	local profilesByUserId: { [number]: any }
	local currencyCalls: { { player: any, currencyType: string, amount: number, reason: string? } }
	local notifyCalls: { { player: any, args: { any } } }
	local originalGetService = service._getService
	local originalGetPlayerByUserId = service._getPlayerByUserId
	local originalGetDay = service._getDay
	local currentDay = 20000

	beforeEach(function()
		friendships = {}
		friendsCallErrors = false
		currentDay = 20000
		service._getDay = function()
			return currentDay
		end
		befriend(100, 200)
		playersByUserId = {}
		profilesByUserId = {}
		currencyCalls = {}
		notifyCalls = {}

		service._getPlayerByUserId = function(_, userId: number)
			return playersByUserId[userId]
		end

		service._getService = function(_, name: string)
			if name == "DataService" then
				return {
					GetDataAsync = function(_, player: any)
						local p = profilesByUserId[player.UserId]
						if p == "FAIL" then
							return Promise.reject("Data failed")
						end
						return Promise.resolve(p or makeProfile())
					end,
				}
			elseif name == "CurrencyService" then
				return {
					Modify = function(_, player: any, currencyType: string, amount: number, reason: string?)
						table.insert(currencyCalls, {
							player = player,
							currencyType = currencyType,
							amount = amount,
							reason = reason,
						})
					end,
				}
			elseif name == "DialogService" then
				return {
					Notify = function(_, player: any, ...)
						table.insert(notifyCalls, {
							player = player,
							args = { ... },
						})
					end,
				}
			end
			return originalGetService(service, name)
		end
	end)

	afterEach(function()
		service._getService = originalGetService
		service._getPlayerByUserId = originalGetPlayerByUserId
		service._getDay = originalGetDay
	end)

	describe("Constants", function()
		it("defines INVITE_REWARD_BOBABUCKS as 50", function()
			expect(service.INVITE_REWARD_BOBABUCKS).to.equal(50)
		end)
	end)

	describe("PromptInvite", function()
		it("fires InvitePromptRequested and returns true", function()
			local clientPlayer = makePlayer(123)
			local signalFired = false
			local signalTarget = nil

			local originalSignal = service.Client.InvitePromptRequested
			service.Client.InvitePromptRequested = {
				Fire = function(_self, target)
					signalFired = true
					signalTarget = target
				end,
			} :: any

			local result = service:PromptInvite(clientPlayer :: any)
			expect(result).to.equal(true)
			expect(signalFired).to.equal(true)
			expect(signalTarget).to.equal(clientPlayer)

			service.Client.InvitePromptRequested = originalSignal
		end)
	end)

	describe("ProcessPlayerJoin", function()
		it("ignores player joining without FollowUserId or join data", function()
			local player = makePlayer(100, nil, nil)
			service:ProcessPlayerJoin(player :: any)
			expect(#currencyCalls).to.equal(0)
			expect(#notifyCalls).to.equal(0)
		end)

		it("ignores player joining with FollowUserId <= 0", function()
			local player = makePlayer(100, 0, nil)
			service:ProcessPlayerJoin(player :: any)
			expect(#currencyCalls).to.equal(0)
			expect(#notifyCalls).to.equal(0)
		end)

		it("ignores self-invite when FollowUserId equals player's UserId", function()
			local player = makePlayer(100, 100, nil)
			playersByUserId[100] = player
			service:ProcessPlayerJoin(player :: any)
			expect(#currencyCalls).to.equal(0)
			expect(#notifyCalls).to.equal(0)
		end)

		it("ignores when inviter player cannot be found", function()
			local player = makePlayer(100, 200, nil)
			-- inviter 200 is not in playersByUserId
			service:ProcessPlayerJoin(player :: any)
			expect(#currencyCalls).to.equal(0)
			expect(#notifyCalls).to.equal(0)
		end)

		it("rewards inviter on first join of a friend via FollowUserId", function()
			local inviter = makePlayer(200)
			local player = makePlayer(100, 200, nil)
			playersByUserId[200] = inviter

			local inviterProfile = makeProfile()
			profilesByUserId[200] = inviterProfile

			service:ProcessPlayerJoin(player :: any)

			-- Check inviter profile record
			expect(inviterProfile.Data.InvitedFriends["100"]).to.equal(true)

			-- Check currency reward
			expect(#currencyCalls).to.equal(1)
			expect(currencyCalls[1].player).to.equal(inviter)
			expect(currencyCalls[1].currencyType).to.equal("BobaBucks")
			expect(currencyCalls[1].amount).to.equal(50)
			expect(currencyCalls[1].reason).to.equal("FriendInvite")

			-- Check notification
			expect(#notifyCalls).to.equal(1)
			expect(notifyCalls[1].player).to.equal(inviter)
			expect(notifyCalls[1].args[1]).to.equal("Friend Joined!")
		end)

		it("rewards inviter via GetJoinData FollowUserId fallback", function()
			local inviter = makePlayer(200)
			local player = makePlayer(100, 0, { FollowUserId = 200 })
			playersByUserId[200] = inviter

			local inviterProfile = makeProfile()
			profilesByUserId[200] = inviterProfile

			service:ProcessPlayerJoin(player :: any)

			expect(inviterProfile.Data.InvitedFriends["100"]).to.equal(true)
			expect(#currencyCalls).to.equal(1)
			expect(currencyCalls[1].amount).to.equal(50)
		end)

		it("rewards inviter via GetJoinData TeleportData.FollowUserId fallback", function()
			local inviter = makePlayer(200)
			local player = makePlayer(100, 0, { TeleportData = { FollowUserId = 200 } })
			playersByUserId[200] = inviter

			local inviterProfile = makeProfile()
			profilesByUserId[200] = inviterProfile

			service:ProcessPlayerJoin(player :: any)

			expect(inviterProfile.Data.InvitedFriends["100"]).to.equal(true)
			expect(#currencyCalls).to.equal(1)
			expect(currencyCalls[1].amount).to.equal(50)
		end)

		it("does not reward inviter twice for the same friend (idempotence)", function()
			local inviter = makePlayer(200)
			local player = makePlayer(100, 200, nil)
			playersByUserId[200] = inviter

			local inviterProfile = makeProfile({ ["100"] = true })
			profilesByUserId[200] = inviterProfile

			service:ProcessPlayerJoin(player :: any)

			expect(#currencyCalls).to.equal(0)
			expect(#notifyCalls).to.equal(0)
		end)

		it("handles DataService failure gracefully without throwing", function()
			local inviter = makePlayer(200)
			local player = makePlayer(100, 200, nil)
			playersByUserId[200] = inviter
			profilesByUserId[200] = "FAIL"

			expect(function()
				service:ProcessPlayerJoin(player :: any)
			end).never.to.throw()

			expect(#currencyCalls).to.equal(0)
			expect(#notifyCalls).to.equal(0)
		end)
	end)

	describe("X10-HARDEN anti-farm gates", function()
		local function setup(joinerId: number, accountAge: number?)
			local inviter = playersByUserId[200] or makePlayer(200)
			playersByUserId[200] = inviter
			if not profilesByUserId[200] then
				profilesByUserId[200] = makeProfile()
			end
			local joiner = makePlayer(joinerId, 200, nil, accountAge)
			profilesByUserId[joinerId] = profilesByUserId[joinerId] or makeProfile()
			return joiner, profilesByUserId[200], profilesByUserId[joinerId]
		end

		it("does not reward when the joiner is not the inviter's friend", function()
			local joiner, inviterProfile = setup(300)
			service:ProcessPlayerJoin(joiner :: any)
			expect(#currencyCalls).to.equal(0)
			expect(inviterProfile.Data.InvitedFriends["300"]).to.equal(nil)
		end)

		it("does not reward when IsFriendsWith errors", function()
			friendsCallErrors = true
			local joiner = setup(100)
			expect(function()
				service:ProcessPlayerJoin(joiner :: any)
			end).never.to.throw()
			expect(#currencyCalls).to.equal(0)
		end)

		it("does not reward when the joiner's account is younger than 7 days", function()
			local joiner, inviterProfile = setup(100, 6)
			service:ProcessPlayerJoin(joiner :: any)
			expect(#currencyCalls).to.equal(0)
			expect(inviterProfile.Data.InvitedFriends["100"]).to.equal(nil)
		end)

		it("rewards at exactly 7 days and marks the joiner as rewarded", function()
			local joiner, _, joinerProfile = setup(100, 7)
			service:ProcessPlayerJoin(joiner :: any)
			expect(#currencyCalls).to.equal(1)
			expect(joinerProfile.Data.InviteRewardedBy).to.equal(200)
		end)

		it("pays at most one reward per invited UserId ever, across inviters", function()
			local joiner, _, joinerProfile = setup(100)
			joinerProfile.Data.InviteRewardedBy = 999
			service:ProcessPlayerJoin(joiner :: any)
			expect(#currencyCalls).to.equal(0)
		end)

		it("caps rewards per inviter per day and resets the next day", function()
			local cap = service.MAX_INVITE_REWARDS_PER_DAY
			for i = 1, cap + 1 do
				local joinerId = 1000 + i
				befriend(200, joinerId)
				local joiner = setup(joinerId)
				service:ProcessPlayerJoin(joiner :: any)
			end
			expect(#currencyCalls).to.equal(cap)
			expect(profilesByUserId[200].Data.InviteRewardsToday.Count).to.equal(cap)

			currentDay += 1
			befriend(200, 2000)
			service:ProcessPlayerJoin(setup(2000) :: any)
			expect(#currencyCalls).to.equal(cap + 1)
			expect(profilesByUserId[200].Data.InviteRewardsToday.Count).to.equal(1)
		end)
	end)
end
