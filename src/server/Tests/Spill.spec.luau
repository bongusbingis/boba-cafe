-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	Spill.spec.luau
	TestEZ unit tests for Spill cleaning and seated player handling:
	- A seated player with a Seat and SeatWeld is unseated and the SeatWeld is broken prior to PivotTo during spill cleaning.
	- The seat does not move when the character is teleported.
	- Player movement locking and recovery restore player state consistently.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage:WaitForChild("Packages")

	local Janitor = require(Packages.Janitor)
	local Spill = require(ServerScriptService.Server.Modules.SpillService.Spill)

	local function createSeatedPlayer(seatPosition: Vector3, weldParentToCharacter: boolean?)
		local folder = Instance.new("Folder")
		folder.Name = "TestEnvironment"
		folder.Parent = workspace

		local seat = Instance.new("Seat")
		seat.Name = "TestSeat"
		seat.CFrame = CFrame.new(seatPosition)
		seat.Parent = folder

		local character = Instance.new("Model")
		character.Name = "TestCharacter"

		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.CFrame = CFrame.new(seatPosition)
		hrp.Parent = character
		character.PrimaryPart = hrp

		local humanoid = Instance.new("Humanoid")
		humanoid.Sit = true
		humanoid.Parent = character

		local seatWeld = Instance.new("Weld")
		seatWeld.Name = "SeatWeld"
		seatWeld.Part0 = seat
		seatWeld.Part1 = hrp
		if weldParentToCharacter then
			seatWeld.Parent = hrp
		else
			seatWeld.Parent = seat
		end

		character.Parent = folder

		local attributes: { [string]: any } = {}
		local player = {
			Name = "TestCleaner",
			Character = character,
			DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice,
			DevTouchMovementMode = Enum.DevTouchMovementMode.UserChoice,
			GetAttribute = function(_self, name: string): any
				return attributes[name]
			end,
			SetAttribute = function(_self, name: string, value: any)
				attributes[name] = value
			end,
		}

		local function cleanup()
			folder:Destroy()
		end

		return player, character, humanoid, seat, seatWeld, cleanup
	end

	describe("Spill:_UnseatPlayer", function()
		it("unseats the player, destroys SeatWeld in Seat, and leaves seat stationary when character pivots", function()
			local initialSeatPos = Vector3.new(10, 0, 10)
			local player, character, humanoid, seat, seatWeld, cleanup = createSeatedPlayer(initialSeatPos, false)

			expect(humanoid.Sit).to.equal(true)
			expect(seatWeld.Parent).to.equal(seat)

			Spill._UnseatPlayer(Spill, player :: any)

			expect(humanoid.Sit).to.equal(false)
			expect(seat:FindFirstChild("SeatWeld")).to.equal(nil)
			expect(seatWeld.Parent).to.equal(nil)

			-- Pivot character far away to simulate cleaning teleport
			local teleportTarget = CFrame.new(100, 5, 100)
			character:PivotTo(teleportTarget)

			-- Seat position must remain completely unchanged
			local seatDelta = (seat.Position - initialSeatPos).Magnitude
			expect(seatDelta < 0.001).to.equal(true)

			-- Character was moved to teleport position
			local charDelta = (character:GetPivot().Position - teleportTarget.Position).Magnitude
			expect(charDelta < 0.001).to.equal(true)

			cleanup()
		end)

		it("destroys SeatWeld parented to character and prevents seat displacement on pivot", function()
			local initialSeatPos = Vector3.new(20, 0, 20)
			local player, character, humanoid, seat, seatWeld, cleanup = createSeatedPlayer(initialSeatPos, true)

			expect(humanoid.Sit).to.equal(true)
			expect(seatWeld.Parent).to.equal(character.PrimaryPart)

			Spill._UnseatPlayer(Spill, player :: any)

			expect(humanoid.Sit).to.equal(false)
			expect(character:FindFirstChild("SeatWeld", true)).to.equal(nil)
			expect(seatWeld.Parent).to.equal(nil)

			-- Teleport character
			character:PivotTo(CFrame.new(200, 10, 200))

			-- Seat must not have moved
			local seatDelta = (seat.Position - initialSeatPos).Magnitude
			expect(seatDelta < 0.001).to.equal(true)

			cleanup()
		end)

		it("safely handles players who are not seated without error", function()
			local player, _, humanoid, _, _, cleanup = createSeatedPlayer(Vector3.new(0, 0, 0), false)
			humanoid.Sit = false

			expect(function()
				Spill._UnseatPlayer(Spill, player :: any)
			end).never.to.throw()

			expect(humanoid.Sit).to.equal(false)
			cleanup()
		end)

		it("safely handles players without a character", function()
			local playerWithoutChar = {
				Name = "GhostPlayer",
				Character = nil,
			}

			expect(function()
				Spill._UnseatPlayer(Spill, playerWithoutChar :: any)
			end).never.to.throw()
		end)
	end)

	describe("Spill:_RunCleaning unseating and teleportation", function()
		it("unseats player and detaches seat BEFORE PivotTo during Mopping", function()
			local initialSeatPos = Vector3.new(5, 0, 5)
			local player, character, humanoid, seat, seatWeld, cleanup = createSeatedPlayer(initialSeatPos, false)

			local spillFolder = Instance.new("Folder")
			spillFolder.Parent = workspace

			local spillPart = Instance.new("Part")
			spillPart.Name = "SpillPrimaryPart"
			spillPart.CFrame = CFrame.new(50, 0, 50)
			spillPart.Parent = spillFolder

			local spillModel = Instance.new("Model")
			spillModel.PrimaryPart = spillPart
			spillPart.Parent = spillModel
			spillModel.Parent = spillFolder

			local prompt = Instance.new("ProximityPrompt")
			prompt.Parent = spillPart

			local mockTrack = {
				Length = 0.05,
				Animation = Instance.new("Animation"),
				Play = function() end,
				Stop = function() end,
				AddItems = function() end,
				GetMarkerReachedSignal = function()
					return {
						Connect = function()
							return {
								Disconnect = function() end,
							}
						end,
					}
				end,
			}

			local finishCalled = false
			local mockSpill = {
				Janitor = Janitor.new(),
				Cleaning = false,
				Destroyed = false,
				Type = "Mopping",
				Prompt = prompt,
				Object = spillModel,
				_LockPlayerMovement = Spill._LockPlayerMovement,
				_UnlockPlayerMovement = Spill._UnlockPlayerMovement,
				_UnseatPlayer = Spill._UnseatPlayer,
				_GetCleaningTools = function()
					return Instance.new("Part"), Instance.new("Part")
				end,
				_GetAnimation = function()
					return mockTrack
				end,
				_FinishCleaning = function(_self, p, _anim, rightTool, leftTool)
					finishCalled = true
					rightTool:Destroy()
					leftTool:Destroy()
					_self:_UnlockPlayerMovement(p)
					p:SetAttribute("CleaningSpill", nil)
				end,
			}

			expect(humanoid.Sit).to.equal(true)
			expect(seatWeld.Parent).to.equal(seat)

			Spill._RunCleaning(mockSpill :: any, player :: any)

			-- Player is unseated and seat weld is broken
			expect(humanoid.Sit).to.equal(false)
			expect(seat:FindFirstChild("SeatWeld")).to.equal(nil)
			expect(seatWeld.Parent).to.equal(nil)

			-- Seat did not move during PivotTo
			local seatDelta = (seat.Position - initialSeatPos).Magnitude
			expect(seatDelta < 0.001).to.equal(true)

			-- Character was pivoted near the spill
			local charPos = character:GetPivot().Position
			local distToSpill = (charPos - spillPart.Position).Magnitude
			expect(distToSpill < 10).to.equal(true)

			expect(finishCalled).to.equal(true)

			mockSpill.Janitor:Cleanup()
			spillFolder:Destroy()
			cleanup()
		end)
	end)

	describe("Spill:_RecoverFromFailedCleaning", function()
		it("restores player movement, resets attribute, and re-arms prompt", function()
			local player, _character, humanoid, _, _, cleanup = createSeatedPlayer(Vector3.new(0, 0, 0), false)

			local prompt = Instance.new("ProximityPrompt")
			prompt.Enabled = false

			local mockSpill = {
				Cleaning = true,
				Destroyed = false,
				Prompt = prompt,
				_UnlockPlayerMovement = Spill._UnlockPlayerMovement,
			}

			-- Simulate in-progress cleaning state
			player:SetAttribute("CleaningSpill", true)
			player.DevComputerMovementMode = Enum.DevComputerMovementMode.Scriptable
			player.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
			humanoid.AutoRotate = false

			Spill._RecoverFromFailedCleaning(mockSpill :: any, player :: any)

			expect(player:GetAttribute("CleaningSpill")).to.equal(nil)
			expect(player.DevComputerMovementMode).to.equal(Enum.DevComputerMovementMode.UserChoice)
			expect(player.DevTouchMovementMode).to.equal(Enum.DevTouchMovementMode.UserChoice)
			expect(humanoid.AutoRotate).to.equal(true)
			expect(mockSpill.Cleaning).to.equal(false)
			expect(prompt.Enabled).to.equal(true)

			prompt:Destroy()
			cleanup()
		end)
	end)
end
