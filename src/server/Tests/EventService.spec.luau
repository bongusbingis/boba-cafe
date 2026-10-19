-- selene: allow(undefined_variable)
--[[
	EventService.spec.luau
	Unit tests for EventConfig and EventService (REVIVAL-001 M4-EVENTS, DEC-032).
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local Workspace = game:GetService("Workspace")

	local EventConfig = require(ReplicatedStorage.Shared.Configuration.EventConfig)
	local EventService = require(ServerScriptService.Server.Modules.EventService) :: any
	local Rules = require(ServerScriptService.Server.Modules.CustomerService.Rules)
	local TreasureHuntService = require(ServerScriptService.Server.Modules.TreasureHuntService) :: any

	describe("EventConfig", function()
		it("defines correct intervals and requirements", function()
			expect(EventConfig.EVENT_DURATION_SECONDS).to.equal(600)
			expect(EventConfig.HOST_COOLDOWN_SECONDS).to.equal(1800)
			expect(EventConfig.AUTO_EVENT_INTERVAL_SECONDS).to.equal(3600)
			expect(EventConfig.MIN_STAFF_RANK).to.equal(10)
		end)

		it("defines the 3 core server events", function()
			local rushHour = EventConfig.EVENTS.RushHour
			expect(rushHour).to.be.ok()
			expect(rushHour.Name).to.equal("Rush Hour")
			expect(rushHour.Attribute).to.equal("RushHour")

			local karenRush = EventConfig.EVENTS.KarenRush
			expect(karenRush).to.be.ok()
			expect(karenRush.Name).to.equal("Karen Day")
			expect(karenRush.Attribute).to.equal("KarenRush")

			local treasureFrenzy = EventConfig.EVENTS.TreasureFrenzy
			expect(treasureFrenzy).to.be.ok()
			expect(treasureFrenzy.Name).to.equal("Treasure Frenzy")
			expect(treasureFrenzy.Attribute).to.equal("TreasureFrenzy")
		end)
	end)

	describe("EventService", function()
		local simulatedTime: number
		local notifiedPlayers: { { player: any, notification: any } }

		local function makePlayer(name: string, userId: number, rank: number, isAdmin: boolean?)
			local attrs: { [string]: any } = {}
			if isAdmin then
				attrs.IsAdmin = true
			end
			return {
				Name = name,
				DisplayName = name,
				UserId = userId,
				Rank = rank,
				GetAttribute = function(_self, key: string)
					return attrs[key]
				end,
				SetAttribute = function(_self, key: string, val: any)
					attrs[key] = val
				end,
			}
		end

		beforeEach(function()
			simulatedTime = 100000
			notifiedPlayers = {}

			EventService._activeEvent = nil
			EventService._activeEventDef = nil
			EventService._activeEventEndTime = 0
			EventService._activeHost = nil
			EventService._hostCooldownEnd = 0
			EventService._currentEventToken = nil

			EventService._nowOverride = function()
				return simulatedTime
			end

			EventService._rankOverride = function(player: any)
				return player.Rank or 1
			end

			EventService._getService = function(_self, name: string)
				if name == "DialogService" then
					return {
						Notify = function(_s, player: any, notif: any)
							table.insert(notifiedPlayers, { player = player, notification = notif })
						end,
					}
				end
				return nil
			end

			Workspace:SetAttribute("RushHour", false)
			Workspace:SetAttribute("KarenRush", false)
			Workspace:SetAttribute("TreasureFrenzy", false)
		end)

		afterEach(function()
			EventService._activeEvent = nil
			EventService._activeEventDef = nil
			EventService._activeEventEndTime = 0
			EventService._activeHost = nil
			EventService._hostCooldownEnd = 0
			EventService._currentEventToken = nil
			EventService._nowOverride = nil
			EventService._rankOverride = nil

			Workspace:SetAttribute("RushHour", false)
			Workspace:SetAttribute("KarenRush", false)
			Workspace:SetAttribute("TreasureFrenzy", false)
		end)

		describe("StartEvent & Overlap Rejection", function()
			it("starts an automated event successfully and sets attribute", function()
				local success, err = EventService:StartEvent("RushHour", nil)
				expect(success).to.equal(true)
				expect(err).to.equal(nil)

				expect(Workspace:GetAttribute("RushHour")).to.equal(true)

				local status = EventService:GetActiveEvent()
				expect(status.EventName).to.equal("RushHour")
				expect(status.TimeRemaining).to.equal(600)
			end)

			it("rejects unknown event name", function()
				local success, err = EventService:StartEvent("InvalidEvent", nil)
				expect(success).to.equal(false)
				expect(string.find(err or "", "Unknown event")).to.be.ok()
			end)

			it("rejects starting a second event while one is active", function()
				local ok1 = EventService:StartEvent("RushHour", nil)
				expect(ok1).to.equal(true)

				local ok2, err2 = EventService:StartEvent("KarenRush", nil)
				expect(ok2).to.equal(false)
				expect(err2).to.equal("An event is already active")
			end)
		end)

		describe("Staff Rank Validation", function()
			it("rejects players below minimum staff rank", function()
				local lowRankPlayer = makePlayer("LowStaff", 1009, 9)
				local ok, err = EventService:StartEvent("RushHour", lowRankPlayer)
				expect(ok).to.equal(false)
				expect(err).to.equal("Insufficient rank to host an event")
				expect(Workspace:GetAttribute("RushHour")).to.equal(false)
			end)

			it("accepts players at or above minimum staff rank", function()
				local validStaff = makePlayer("GoodStaff", 1010, 10)
				local ok, err = EventService:StartEvent("RushHour", validStaff)
				expect(ok).to.equal(true)
				expect(err).to.equal(nil)
				expect(Workspace:GetAttribute("RushHour")).to.equal(true)
			end)

			it("accepts admin players regardless of group rank", function()
				local adminPlayer = makePlayer("AdminUser", 1001, 1, true)
				local ok, err = EventService:StartEvent("KarenRush", adminPlayer)
				expect(ok).to.equal(true)
				expect(err).to.equal(nil)
				expect(Workspace:GetAttribute("KarenRush")).to.equal(true)
			end)
		end)

		describe("Host Cooldown Enforcement", function()
			it("enforces cooldown for staff hosted events", function()
				local staffPlayer = makePlayer("Staff1", 1010, 10)
				local ok = EventService:StartEvent("RushHour", staffPlayer)
				expect(ok).to.equal(true)

				-- End the active event
				EventService:EndActiveEvent()
				expect(EventService:GetActiveEvent().EventName).to.equal(nil)
				expect(Workspace:GetAttribute("RushHour")).to.equal(false)

				local cooldownRemaining = EventService:GetActiveEvent().HostCooldownRemaining
				expect(cooldownRemaining).to.equal(1800)

				-- Another staff member attempts to host while cooldown is active
				local staffPlayer2 = makePlayer("Staff2", 1015, 15)
				local ok2, err2 = EventService:StartEvent("KarenRush", staffPlayer2)
				expect(ok2).to.equal(false)
				expect(err2).to.equal("Host cooldown is active")

				-- Advance time beyond cooldown
				simulatedTime += 1801
				expect(EventService:GetActiveEvent().HostCooldownRemaining).to.equal(0)

				-- Now staff can host again
				local ok3, err3 = EventService:StartEvent("TreasureFrenzy", staffPlayer2)
				expect(ok3).to.equal(true)
				expect(err3).to.equal(nil)
				expect(Workspace:GetAttribute("TreasureFrenzy")).to.equal(true)
			end)
		end)

		describe("Duration expiration task", function()
			it("clears workspace attribute and sets cooldown when duration expires", function()
				local ok = EventService:StartEvent("TreasureFrenzy", nil, 0.05)
				expect(ok).to.equal(true)
				expect(Workspace:GetAttribute("TreasureFrenzy")).to.equal(true)

				task.wait(0.08)

				local status = EventService:GetActiveEvent()
				expect(status.EventName).to.equal(nil)
				expect(status.TimeRemaining).to.equal(0)
				expect(Workspace:GetAttribute("TreasureFrenzy")).to.equal(false)
				expect(status.HostCooldownRemaining).to.equal(1800)
			end)
		end)

		describe("Client functions", function()
			it("allows client StartEvent invocation with staff player", function()
				local staff = makePlayer("StaffClient", 1010, 10)
				local ok, err = EventService.Client:StartEvent(staff :: any, "KarenRush")
				expect(ok).to.equal(true)
				expect(err).to.equal(nil)
				expect(Workspace:GetAttribute("KarenRush")).to.equal(true)
			end)

			it("validates client eventName argument type", function()
				local staff = makePlayer("StaffClient", 1010, 10)
				local ok, err = EventService.Client:StartEvent(staff :: any, 123 :: any)
				expect(ok).to.equal(false)
				expect(err).to.equal("Invalid event name")
			end)

			it("allows client GetActiveEvent invocation", function()
				EventService:StartEvent("RushHour", nil)
				local status = EventService.Client:GetActiveEvent(nil :: any)
				expect(status.EventName).to.equal("RushHour")
			end)
		end)
	end)

	describe("Event Hooks", function()
		afterEach(function()
			Workspace:SetAttribute("KarenRush", false)
			Workspace:SetAttribute("TreasureFrenzy", false)
		end)

		describe("CustomerService/Rules KarenRush hook", function()
			it("reverts to standard MinLevel and Chance when KarenRush is inactive", function()
				Workspace:SetAttribute("KarenRush", false)
				-- At level 5, Karen cannot spawn (normal Karen MinLevel is 10)
				expect(Rules.PickVariant(5, 0.02)).to.equal(nil)
			end)

			it("overrides Karen chance to 0.50 and min level to 1 when KarenRush is active", function()
				Workspace:SetAttribute("KarenRush", true)
				-- At level 1, roll < 0.50 yields Karen
				expect(Rules.PickVariant(1, 0.25)).to.equal("Karen")
				expect(Rules.PickVariant(1, 0.49)).to.equal("Karen")
				-- At level 1, roll >= 0.50 yields nil (VIP min level is 6)
				expect(Rules.PickVariant(1, 0.51)).to.equal(nil)
			end)
		end)

		describe("TreasureHuntService TreasureFrenzy hook", function()
			it("uses standard capacity and respawn delay when TreasureFrenzy is inactive", function()
				Workspace:SetAttribute("TreasureFrenzy", false)
				expect(TreasureHuntService:_getMaxChests()).to.equal(5)
				expect(TreasureHuntService:_getRespawnDelay()).to.equal(90)
			end)

			it("scales max chests to 8 and respawn delay to 15s when TreasureFrenzy is active", function()
				Workspace:SetAttribute("TreasureFrenzy", true)
				expect(TreasureHuntService:_getMaxChests()).to.equal(8)
				expect(TreasureHuntService:_getRespawnDelay()).to.equal(15)
			end)
		end)
	end)
end
