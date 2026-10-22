-- selene: allow(undefined_variable)
--[[
	PassSettingsService.spec.luau
	Tests for PassSettingsService walk speed perk persistence and application.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")

	local Promise = require(ReplicatedStorage.Packages.Promise)
	local service = require(ServerScriptService.Server.Modules.PassSettingsService)

	local originalGetService = service._getService

	local function createFakeCharacter(): (Model, Humanoid)
		local character = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.WalkSpeed = 16
		humanoid.Parent = character
		return character, humanoid
	end

	local function createFakePlayer(userId: number, character: Model?)
		local attributes = {}
		local fakePlayer = {
			UserId = userId,
			Name = "Player_" .. userId,
			Parent = Players,
			Character = character,
			SetAttribute = function(_self, key: string, value: any)
				attributes[key] = value
			end,
			GetAttribute = function(_self, key: string)
				return attributes[key]
			end,
		}
		return fakePlayer :: any
	end

	beforeEach(function()
		service._owned = {}
		service._settings = {}
	end)

	afterEach(function()
		service._getService = originalGetService
		service._owned = {}
		service._settings = {}
	end)

	describe("_loadSettings", function()
		it("correctly populates FasterWalkSpeed = true from DataService proxy table", function()
			local player = createFakePlayer(1001)
			service._getService = function(_self, name: string): any
				if name == "DataService" then
					return {
						GetDataAsync = function(_ds, _p)
							return Promise.resolve({
								Settings = {
									FasterWalkSpeed = true,
								},
							})
						end,
					}
				end
				return originalGetService(service, name)
			end

			service:_loadSettings(player)

			expect(service._settings[player]).to.be.ok()
			expect(service._settings[player]["FasterWalkSpeed"]).to.equal(true)
		end)

		it("correctly populates FasterWalkSpeed = true from DataService raw profile (data.Data.Settings)", function()
			local player = createFakePlayer(1002)
			service._getService = function(_self, name: string): any
				if name == "DataService" then
					return {
						GetDataAsync = function(_ds, _p)
							return Promise.resolve({
								Data = {
									Settings = {
										FasterWalkSpeed = true,
									},
								},
							})
						end,
					}
				end
				return originalGetService(service, name)
			end

			service:_loadSettings(player)

			expect(service._settings[player]).to.be.ok()
			expect(service._settings[player]["FasterWalkSpeed"]).to.equal(true)
		end)

		it("falls back to empty settings when DataService promise rejects", function()
			local player = createFakePlayer(1003)
			service._getService = function(_self, name: string): any
				if name == "DataService" then
					return {
						GetDataAsync = function(_ds, _p)
							return Promise.reject("Data failed to load")
						end,
					}
				end
				return originalGetService(service, name)
			end

			service:_loadSettings(player)

			expect(service._settings[player]).to.be.ok()
			expect(service._settings[player]["FasterWalkSpeed"]).to.equal(nil)
		end)

		it("does not store settings if player leaves before load finishes", function()
			local player = createFakePlayer(1004)
			player.Parent = nil
			service._getService = function(_self, name: string): any
				if name == "DataService" then
					return {
						GetDataAsync = function(_ds, _p)
							return Promise.resolve({
								Settings = {
									FasterWalkSpeed = true,
								},
							})
						end,
					}
				end
				return originalGetService(service, name)
			end

			service:_loadSettings(player)

			expect(service._settings[player]).to.equal(nil)
		end)
	end)

	describe("IsWalkSpeedActive", function()
		it("returns true when owned and setting is on", function()
			local player = createFakePlayer(2001)
			service._owned[player] = { WalkSpeed = true }
			service._settings[player] = { FasterWalkSpeed = true }

			expect(service:IsWalkSpeedActive(player)).to.equal(true)
		end)

		it("returns false when perk is not owned even if setting is on", function()
			local player = createFakePlayer(2002)
			service._owned[player] = { WalkSpeed = false }
			service._settings[player] = { FasterWalkSpeed = true }

			expect(service:IsWalkSpeedActive(player)).to.equal(false)
		end)

		it("returns false when perk is owned but setting is off or nil", function()
			local player = createFakePlayer(2003)
			service._owned[player] = { WalkSpeed = true }
			service._settings[player] = { FasterWalkSpeed = false }

			expect(service:IsWalkSpeedActive(player)).to.equal(false)

			service._settings[player] = {}
			expect(service:IsWalkSpeedActive(player)).to.equal(false)
		end)
	end)

	describe("_applySpeed", function()
		it("sets humanoid.WalkSpeed to 32 when active", function()
			local character, humanoid = createFakeCharacter()
			local player = createFakePlayer(3001, character)

			service._owned[player] = { WalkSpeed = true }
			service._settings[player] = { FasterWalkSpeed = true }

			service:_applySpeed(player)

			expect(humanoid.WalkSpeed).to.equal(32)
			character:Destroy()
		end)

		it("sets humanoid.WalkSpeed to 16 when inactive", function()
			local character, humanoid = createFakeCharacter()
			humanoid.WalkSpeed = 32
			local player = createFakePlayer(3002, character)

			service._owned[player] = { WalkSpeed = true }
			service._settings[player] = { FasterWalkSpeed = false }

			service:_applySpeed(player)

			expect(humanoid.WalkSpeed).to.equal(16)
			character:Destroy()
		end)

		it("sets humanoid.WalkSpeed to 32 upon character spawn with character argument", function()
			local character, humanoid = createFakeCharacter()
			local player = createFakePlayer(3003, character)

			service._owned[player] = { WalkSpeed = true }
			service._settings[player] = { FasterWalkSpeed = true }

			service:_applySpeed(player, character)

			expect(humanoid.WalkSpeed).to.equal(32)
			character:Destroy()
		end)
	end)
end
