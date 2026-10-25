-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	RankingService.spec.luau
	Tests for the Open Cloud Group Ranking Service.
]]

return function()
	local HttpService = game:GetService("HttpService")
	local ServerScriptService = game:GetService("ServerScriptService")

	local RankingService = require(ServerScriptService.Server.Modules.RankingService) :: any

	local originalGetSecret = RankingService._getSecret
	local originalRequestAsync = RankingService._requestAsync

	local mockSecrets: { [string]: any } = {}
	local mockRequests: { [string]: (options: any) -> any } = {}
	local capturedRequests: { any } = {}

	beforeEach(function()
		mockSecrets = {
			["OPEN_CLOUD_API_KEY"] = "mock-secret-key-123",
		}
		capturedRequests = {}
		mockRequests = {}

		RankingService._secretName = "OPEN_CLOUD_API_KEY"
		RankingService._rankingApiClient = nil
		RankingService:InvalidateRolesCache()

		RankingService._getSecret = function(name: string)
			local secret = mockSecrets[name]
			if secret ~= nil then
				return secret
			end
			error("Secret not found: " .. tostring(name))
		end

		RankingService._requestAsync = function(options: any)
			table.insert(capturedRequests, options)
			for pattern, handler in mockRequests do
				if string.find(options.Url, pattern, 1, true) then
					return handler(options)
				end
			end

			-- Default mock responses
			if string.find(options.Url, "/roles", 1, true) then
				return {
					Success = true,
					StatusCode = 200,
					StatusMessage = "OK",
					Body = HttpService:JSONEncode({
						groupRoles = {
							{
								path = "groups/3174578/roles/101",
								id = "101",
								displayName = "Trainee",
								rank = 6,
							},
							{
								path = "groups/3174578/roles/102",
								id = "102",
								displayName = "Junior Barista",
								rank = 7,
							},
							{
								path = "groups/3174578/roles/103",
								id = "103",
								displayName = "Barista",
								rank = 8,
							},
							{
								path = "groups/3174578/roles/104",
								id = "104",
								displayName = "Senior Barista",
								rank = 9,
							},
							{
								path = "groups/3174578/roles/105",
								id = "105",
								displayName = "Head Barista",
								rank = 10,
							},
						},
					}),
				}
			elseif string.find(options.Url, "/memberships", 1, true) and options.Method == "GET" then
				return {
					Success = true,
					StatusCode = 200,
					StatusMessage = "OK",
					Body = HttpService:JSONEncode({
						groupMemberships = {
							{
								path = "groups/3174578/memberships/12345",
								user = "users/12345",
								role = "groups/3174578/roles/101",
							},
						},
					}),
				}
			elseif options.Method == "PATCH" then
				return {
					Success = true,
					StatusCode = 200,
					StatusMessage = "OK",
					Body = HttpService:JSONEncode({
						path = "groups/3174578/memberships/12345",
						user = "users/12345",
						role = "groups/3174578/roles/103",
					}),
				}
			end

			return {
				Success = false,
				StatusCode = 404,
				StatusMessage = "Not Found",
				Body = "{}",
			}
		end
	end)

	afterEach(function()
		RankingService._getSecret = originalGetSecret
		RankingService._requestAsync = originalRequestAsync
	end)

	describe("Rank range validation (6-10)", function()
		it("accepts valid ranks 6, 7, 8, 9, 10", function()
			for rank = 6, 10 do
				expect(RankingService.IsValidRank(rank)).to.equal(true)
			end
		end)

		it("rejects ranks below 6", function()
			expect(RankingService.IsValidRank(5)).to.equal(false)
			expect(RankingService.IsValidRank(1)).to.equal(false)
			expect(RankingService.IsValidRank(0)).to.equal(false)
			expect(RankingService.IsValidRank(-5)).to.equal(false)

			local ok, err = RankingService:SetRankAsync(12345, 5)
			expect(ok).to.equal(false)
			expect(string.find(err or "", "6 to 10", 1, true) ~= nil).to.equal(true)
		end)

		it("rejects ranks above 10", function()
			expect(RankingService.IsValidRank(11)).to.equal(false)
			expect(RankingService.IsValidRank(15)).to.equal(false)
			expect(RankingService.IsValidRank(255)).to.equal(false)

			local ok, err = RankingService:SetRankAsync(12345, 11)
			expect(ok).to.equal(false)
			expect(string.find(err or "", "6 to 10", 1, true) ~= nil).to.equal(true)
		end)

		it("rejects non-integer ranks", function()
			expect(RankingService.IsValidRank(7.5)).to.equal(false)
			local ok, _ = RankingService:SetRankAsync(12345, 7.5)
			expect(ok).to.equal(false)
		end)

		it("rejects non-number ranks", function()
			expect(RankingService.IsValidRank("7")).to.equal(false)
			expect(RankingService.IsValidRank(nil)).to.equal(false)
			expect(RankingService.IsValidRank({})).to.equal(false)
		end)
	end)

	describe("Secret handling", function()
		it("fails gracefully with informative message when secret is missing", function()
			mockSecrets = {}
			local ok, err = RankingService:SetRankAsync(12345, 7)
			expect(ok).to.equal(false)
			expect(string.find(err or "", "secret", 1, true) ~= nil).to.equal(true)
		end)

		it("respects custom secret name configured via SetSecretName", function()
			RankingService:SetSecretName("CUSTOM_RANK_SECRET")
			mockSecrets = {
				["CUSTOM_RANK_SECRET"] = "custom-secret-value",
			}

			local ok, _ = RankingService:SetRankAsync(12345, 8)
			expect(ok).to.equal(true)
		end)
	end)

	describe("Group role resolution", function()
		it("finds the role resource corresponding to rank", function()
			local role, err = RankingService:GetRoleForRankAsync(8)
			expect(err).to.equal(nil)
			expect(role ~= nil).to.equal(true)
			expect(role.rank).to.equal(8)
			expect(role.displayName).to.equal("Barista")
			expect(role.path).to.equal("groups/3174578/roles/103")
		end)

		it("returns an error if the rank is not defined in the group", function()
			local ok, err = RankingService:GetRoleForRankAsync(4)
			expect(ok).to.equal(nil)
			expect(string.find(err or "", "Invalid rank", 1, true) ~= nil).to.equal(true)
		end)
	end)

	describe("User membership & ranking flow", function()
		it("successfully patches membership when rank is changed", function()
			local ok, message = RankingService:SetRankAsync(12345, 8)
			expect(ok).to.equal(true)
			expect(string.find(message or "", "Barista", 1, true) ~= nil).to.equal(true)

			-- Verify PATCH request was executed with correct payload
			local patchReq = nil
			for _, req in capturedRequests do
				if req.Method == "PATCH" then
					patchReq = req
					break
				end
			end
			expect(patchReq ~= nil).to.equal(true)
			expect(patchReq.Url).to.equal("https://apis.roblox.com/cloud/v2/groups/3174578/memberships/12345")
			local body = HttpService:JSONDecode(patchReq.Body)
			expect(body.role).to.equal("groups/3174578/roles/103")
		end)

		it("returns success early without PATCH when user already has the target rank", function()
			-- User 12345 already has rank 6 ("groups/3174578/roles/101")
			local ok, message = RankingService:SetRankAsync(12345, 6)
			expect(ok).to.equal(true)
			expect(string.find(message or "", "already has rank", 1, true) ~= nil).to.equal(true)

			-- Verify no PATCH was performed
			for _, req in capturedRequests do
				expect(req.Method ~= "PATCH").to.equal(true)
			end
		end)

		it("fails if the user is not in the group", function()
			mockRequests["/memberships"] = function()
				return {
					Success = true,
					StatusCode = 200,
					StatusMessage = "OK",
					Body = HttpService:JSONEncode({
						groupMemberships = {},
					}),
				}
			end

			local ok, err = RankingService:SetRankAsync(99999, 7)
			expect(ok).to.equal(false)
			expect(string.find(err or "", "not a member", 1, true) ~= nil).to.equal(true)
		end)

		it("handles Open Cloud HTTP error responses", function()
			mockRequests["/roles"] = function()
				return {
					Success = false,
					StatusCode = 403,
					StatusMessage = "Forbidden",
					Body = HttpService:JSONEncode({
						message = "Insufficient API key permissions",
					}),
				}
			end

			local ok, err = RankingService:SetRankAsync(12345, 7)
			expect(ok).to.equal(false)
			expect(string.find(err or "", "403", 1, true) ~= nil).to.equal(true)
		end)
	end)

	describe("Calling conventions", function()
		it("supports colon syntax RankingService:SetRankAsync(userId, rank)", function()
			local ok, _ = RankingService:SetRankAsync(12345, 8)
			expect(ok).to.equal(true)
		end)

		it("supports dot syntax RankingService.SetRank(userId, rank)", function()
			local ok, _ = RankingService.SetRank(12345, 8)
			expect(ok).to.equal(true)
		end)

		it("supports metatable call RankingService(userId, rank)", function()
			local ok, _ = RankingService(12345, 8)
			expect(ok).to.equal(true)
		end)
	end)

	describe("RankingClient integration with GAME_KEY", function()
		it("routes rank updates through injected RankingClient", function()
			local calledGroupId, calledUserId, calledRank
			local mockClient = {
				setRank = function(groupId: number, userId: number, rank: number)
					calledGroupId = groupId
					calledUserId = userId
					calledRank = rank
					return { success = true }
				end,
			}

			RankingService:SetRankingClient(mockClient)
			local ok, msg = RankingService:SetRankViaClientAsync(12345, 9)
			expect(ok).to.equal(true)
			expect(calledGroupId).to.equal(3174578)
			expect(calledUserId).to.equal(12345)
			expect(calledRank).to.equal(9)
			expect(string.find(msg or "", "Successfully", 1, true) ~= nil).to.equal(true)
		end)

		it("returns error message when RankingClient returns an error", function()
			local mockClient = {
				setRank = function(_groupId: number, _userId: number, _rank: number)
					return { error = "User is pending a response." }
				end,
			}

			RankingService:SetRankingClient(mockClient)
			local ok, err = RankingService:SetRankViaClientAsync(12345, 7)
			expect(ok).to.equal(false)
			expect(string.find(err or "", "User is pending", 1, true) ~= nil).to.equal(true)
		end)
	end)
end
