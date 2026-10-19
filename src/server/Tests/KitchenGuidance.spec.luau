-- selene: allow(undefined_variable)
--[[
	KitchenGuidance.spec.luau
	TestEZ tests for the pure logic behind the kitchen hints (REVIVAL-001 M1.5c/d):
	nearest-station choice, the Highlight cap, the beam conditions, the active-spec
	resolver, the current step, and the "Next: <label>" wrong-station text.

	The module lives under StarterPlayerScripts (client). The server test runner can
	read it there, and it touches no Instances, so these run on the server.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterPlayer = game:GetService("StarterPlayer")

	local OrderSpec = require(ReplicatedStorage.Shared.Ordering.OrderSpec)
	local modules = StarterPlayer.StarterPlayerScripts.Client.Modules
	local KitchenGuidance = require(modules.KitchenGuidance)

	local function boba()
		return {
			Kind = "Drink",
			Item = "Boba",
			Size = "Medium",
			Syrup = "Classic Milk Tea",
			Tapioca = "Normal",
			Label = "Medium Custom Boba",
		}
	end

	local function coffee()
		return { Kind = "Drink", Item = "Latte", Size = "Small", Iced = true, Sugar = false, Label = "Small Latte" }
	end

	local function pt(x, y, z)
		return { X = x, Y = y, Z = z }
	end

	describe("NearestIndex", function()
		it("returns nil for no points", function()
			expect(KitchenGuidance.NearestIndex({}, pt(0, 0, 0))).to.equal(nil)
		end)

		it("picks the closest point, so only one of several Milk models is chosen", function()
			local milks = { pt(30, 0, 0), pt(4, 0, 3), pt(-12, 0, 0) }
			expect(KitchenGuidance.NearestIndex(milks, pt(0, 0, 0))).to.equal(2)
			expect(KitchenGuidance.NearestIndex(milks, pt(-20, 0, 0))).to.equal(3)
		end)

		it("keeps the first of a tie", function()
			expect(KitchenGuidance.NearestIndex({ pt(5, 0, 0), pt(-5, 0, 0) }, pt(0, 0, 0))).to.equal(1)
		end)
	end)

	describe("Compute", function()
		it("points at the first station when nothing is held", function()
			local guidance = KitchenGuidance.Compute(boba(), nil)
			expect(guidance.Station).to.equal("Clear Cup")
			expect(guidance.Choice).to.equal("Medium")
			expect(guidance.Label).to.equal("Medium Clear Cup")
			expect(guidance.Current).to.equal(1)
			expect(guidance.IsServe).to.equal(false)
		end)

		it("advances: Milk, then the syrup, then tapioca", function()
			local spec = boba()
			expect(KitchenGuidance.Compute(spec, { Item = "Clear Cup", Size = "Medium" }).Station).to.equal("Milk")
			expect(KitchenGuidance.Compute(spec, { Item = "Milk", Size = "Medium" }).Station).to.equal(
				"Classic Milk Tea Syrup"
			)
			local third =
				KitchenGuidance.Compute(spec, { Item = "Flavored Milk", Size = "Medium", Syrup = "Classic Milk Tea" })
			expect(third.Station).to.equal("Normal Tapioca")
		end)

		it("moves to the Serve step with no station", function()
			local guidance = KitchenGuidance.Compute(
				boba(),
				{ Item = "Boba", Size = "Medium", Syrup = "Classic Milk Tea", Tapioca = "Normal" }
			)
			expect(guidance.IsServe).to.equal(true)
			expect(guidance.Station).to.equal(nil)
			expect(guidance.Label).to.equal("Serve your customer")
		end)

		it("carries the coffee choice at the Coffee Machine", function()
			local guidance = KitchenGuidance.Compute(coffee(), { Item = "Cup", Size = "Small" })
			expect(guidance.Station).to.equal("Coffee Machine")
			expect(guidance.Choice).to.equal("Latte")
		end)

		it("carries the food item at the Food Display", function()
			local guidance =
				KitchenGuidance.Compute({ Kind = "Grab", Item = "Fudge Brownie", Label = "Fudge Brownie" }, nil)
			expect(guidance.Station).to.equal("Food Display")
			expect(guidance.Choice).to.equal("Fudge Brownie")
		end)

		it("gives no guidance for no spec or an item without a chain", function()
			expect(KitchenGuidance.Compute(nil, nil)).to.equal(nil)
			local tea = { Kind = "Drink", Item = "Green Tea", Size = "Small", Iced = false, Label = "Small Green Tea" }
			expect(KitchenGuidance.Compute(tea, nil)).to.equal(nil)
		end)

		it("agrees with OrderSpec.StepState", function()
			local spec = boba()
			local attrs = { Item = "Milk", Size = "Medium" }
			local current = OrderSpec.StepState(spec, attrs)
			expect(KitchenGuidance.Compute(spec, attrs).Current).to.equal(current)
		end)
	end)

	describe("ShouldShowBeam", function()
		local function state(changes)
			local base = { CustomersSeen = 5, ItemSeenBefore = true, IdleSeconds = 0 }
			for key, value in changes do
				base[key] = value
			end
			return base
		end

		it("hides the beam once all three conditions are past", function()
			expect(KitchenGuidance.ShouldShowBeam(state({}))).to.equal(false)
		end)

		it("shows it for the first 3 customers only", function()
			expect(KitchenGuidance.ShouldShowBeam(state({ CustomersSeen = 1 }))).to.equal(true)
			expect(KitchenGuidance.ShouldShowBeam(state({ CustomersSeen = 3 }))).to.equal(true)
			expect(KitchenGuidance.ShouldShowBeam(state({ CustomersSeen = 4 }))).to.equal(false)
		end)

		it("shows it the first time an item appears", function()
			expect(KitchenGuidance.ShouldShowBeam(state({ ItemSeenBefore = false }))).to.equal(true)
		end)

		it("shows it again after 20 s idle", function()
			expect(KitchenGuidance.ShouldShowBeam(state({ IdleSeconds = 19.9 }))).to.equal(false)
			expect(KitchenGuidance.ShouldShowBeam(state({ IdleSeconds = 20 }))).to.equal(true)
		end)
	end)

	describe("WrongStationMessage", function()
		it("says nothing at the right station", function()
			local guidance = KitchenGuidance.Compute(boba(), { Item = "Clear Cup", Size = "Medium" })
			expect(KitchenGuidance.WrongStationMessage(guidance, "Milk")).to.equal(nil)
		end)

		it("names the next step at a wrong station", function()
			local guidance = KitchenGuidance.Compute(boba(), { Item = "Clear Cup", Size = "Medium" })
			expect(KitchenGuidance.WrongStationMessage(guidance, "Taro Syrup")).to.equal("Next: Milk")
			expect(KitchenGuidance.WrongStationMessage(guidance, "Coffee Machine")).to.equal("Next: Milk")
		end)

		it("says to serve once every step is done", function()
			local guidance = KitchenGuidance.Compute(
				boba(),
				{ Item = "Boba", Size = "Medium", Syrup = "Classic Milk Tea", Tapioca = "Normal" }
			)
			expect(KitchenGuidance.WrongStationMessage(guidance, "Milk")).to.equal("Next: Serve your customer")
		end)

		it("ignores neutral stations and a missing order", function()
			local guidance = KitchenGuidance.Compute(boba(), nil)
			expect(KitchenGuidance.WrongStationMessage(guidance, "Sink")).to.equal(nil)
			expect(KitchenGuidance.WrongStationMessage(guidance, "Blender")).to.equal(nil)
			expect(KitchenGuidance.WrongStationMessage(nil, "Milk")).to.equal(nil)
		end)
	end)

	describe("ResolveSpec", function()
		local function never()
			error("should not be called")
		end

		it("returns a spec as it is", function()
			local spec = boba()
			expect(KitchenGuidance.ResolveSpec(spec, never)).to.equal(spec)
		end)

		it("unwraps .Spec and the first entry of a list", function()
			local spec = boba()
			expect(KitchenGuidance.ResolveSpec({ Spec = spec }, never)).to.equal(spec)
			expect(KitchenGuidance.ResolveSpec({ { Spec = spec } }, never)).to.equal(spec)
		end)

		it("resolves an order item through the given function", function()
			local spec = boba()
			local seen
			local resolved = KitchenGuidance.ResolveSpec({ Category = "Drinks", Item = "Boba" }, function(item)
				seen = item
				return spec, nil
			end)
			expect(resolved).to.equal(spec)
			expect(seen.Item).to.equal("Boba")
		end)

		it("resolves an NPC ticket and its NpcModel (M1.4e shape)", function()
			local spec = boba()
			local model = Instance.new("Model")
			local ticket = {
				Id = "Customer1",
				NpcModel = model,
				Label = "Boba",
				Spec = { Category = "Drinks", Item = "Boba", CustomInfo = {}, Size = "Medium" },
				PatienceEnd = 100,
				PatienceTotal = 60,
				Scripted = false,
				Rescue = false,
			}
			local resolved = KitchenGuidance.ResolveSpec(ticket, function()
				return spec, nil
			end)
			expect(resolved).to.equal(spec)
			expect(ticket.NpcModel).to.equal(model)
			model:Destroy()
		end)

		it("returns nil for nothing, junk, or a resolver that errors", function()
			expect(KitchenGuidance.ResolveSpec(nil, never)).to.equal(nil)
			expect(KitchenGuidance.ResolveSpec("x", never)).to.equal(nil)
			expect(KitchenGuidance.ResolveSpec({}, never)).to.equal(nil)
			expect(KitchenGuidance.ResolveSpec({ Category = "A", Item = "B" }, never)).to.equal(nil)
		end)
	end)

	describe("Highlight cap", function()
		it("allows at most 2", function()
			expect(KitchenGuidance.MAX_HIGHLIGHTS).to.equal(2)
		end)
	end)
end
