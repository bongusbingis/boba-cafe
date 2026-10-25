-- selene: allow(undefined_variable)
--[[
	InteractionRunner.spec.luau
	TestEZ tests for the pour held-tool guard: a SkillMoment station validates
	the held tool, then yields on the pour meter. Swapping tools mid-meter must
	fail the sequence instead of stamping the finish onto the new tool.
]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")

	local InteractionRunner = require(ServerScriptService.Server.Modules.KitchenService.InteractionRunner)

	local function makeTool()
		local tool = Instance.new("Tool")
		tool.Name = "TestCup"
		return tool
	end

	local function makePlayerWith(tool: Instance?)
		local character = Instance.new("Model")
		if tool then
			tool.Parent = character
		end
		local attributes = { ClockedIn = true }
		return {
			Name = "PourPlayer",
			Character = character,
			GetAttribute = function(_self, key: string)
				return attributes[key]
			end,
			SetAttribute = function(_self, key: string, value: any)
				attributes[key] = value
			end,
		}
	end

	-- Registry stub: the behaviour action stamps the held tool, like
	-- SetToolAttributes does, and records that it ran.
	local function makeRegistry(applied: { boolean })
		return {
			Get = function(_actionName: string)
				return function(player: any, _model: any, attrs: any)
					applied[1] = true
					local character = player.Character
					local held = character and character:FindFirstChildWhichIsA("Tool")
					if held and typeof(attrs) == "table" then
						for key, value in attrs do
							held:SetAttribute(key, value)
						end
					end
					return true
				end
			end,
		}
	end

	local function makePours(swap: (() -> ())?)
		return {
			AwaitPour = function(_pours: any, _player: any, _recipe: any, _model: any)
				if swap then
					swap()
				end
				return "Perfect"
			end,
		}
	end

	local function runSequence(player: any, pours: any, applied: { boolean })
		local runner = InteractionRunner.new(
			makeRegistry(applied),
			function(_player: any, _reason: string) end,
			nil,
			pours
		)
		return runner:_runSequence(
			player,
			Instance.new("Model"),
			{ { "SetToolAttributes", { Item = "Milk" } } },
			{ SkillMoment = true }
		)
	end

	describe("pour held-tool guard", function()
		it("stamps the finish when the held tool is unchanged across the pour", function()
			local tool = makeTool()
			local applied = { false }
			local result = runSequence(makePlayerWith(tool), makePours(nil), applied)

			expect(result.Success).to.equal(true)
			expect(applied[1]).to.equal(true)
			expect(tool:GetAttribute("Item")).to.equal("Milk")
		end)

		it("fails without stamping when the held tool changes during the pour", function()
			local first = makeTool()
			local player = makePlayerWith(first)
			local character = player.Character
			local applied = { false }
			local second = makeTool()
			local result = runSequence(
				player,
				makePours(function()
					-- The player swaps tools while the meter is open.
					first.Parent = nil
					second.Parent = character
				end),
				applied
			)

			expect(result.Success).to.equal(false)
			expect(result.Error).to.equal("Pour: held tool changed")
			expect(applied[1]).to.equal(false)
			expect(first:GetAttribute("Item")).to.equal(nil)
			expect(second:GetAttribute("Item")).to.equal(nil)
		end)
	end)
end
