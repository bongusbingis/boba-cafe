-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	ToastQueue.spec.luau
	TestEZ tests for the SmallNotification queue policy (REVIVAL-001 REVIEW-FIX P2-2):
	tiers, never-drop tier 1, served collapse, corrective replace, dedupe.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local SmallNotification = require(ReplicatedStorage.Shared.UI.Components.Core.Hud.SmallNotification)

	local function toast(text: string): any
		return { Text = text }
	end

	local function texts(queue): { string }
		local out = {}
		for _, item in queue do
			table.insert(out, item.Text)
		end
		return out
	end

	describe("Classify", function()
		it("puts level up and quest complete in tier 1", function()
			expect(SmallNotification.Classify(toast("Level up! You are now level 2"))).to.equal(1)
			expect(SmallNotification.Classify(toast("Quest complete: Serve 5!"))).to.equal(1)
			expect(SmallNotification.Classify(toast("Your first order! +12 Boba Bucks"))).to.equal(1)
		end)

		it("marks corrective and served toasts", function()
			local _, wrong = SmallNotification.Classify(toast("Wrong drink: Needs ice"))
			local _, station = SmallNotification.Classify(toast("Next: Add boba"))
			local _, clock = SmallNotification.Classify(toast("Clock In to use the kitchen. Tap the clock button."))
			local served, servedKind = SmallNotification.Classify(toast("Order served! +12 · Perfect"))
			expect(wrong).to.equal("Corrective")
			expect(station).to.equal("Corrective")
			expect(clock).to.equal("Corrective")
			expect(servedKind).to.equal("Served")
			expect(served).to.equal(4)
		end)

		it("honours an explicit Priority", function()
			expect(SmallNotification.Classify({ Text = "x", Priority = 1 })).to.equal(1)
		end)
	end)

	describe("Route", function()
		local active = toast("Order served! +10 · Close")

		it("shows when nothing is active", function()
			expect(SmallNotification.Route({}, nil, toast("Hello"))).to.equal("Show")
		end)

		it("never drops a tier 1 toast when the queue overflows", function()
			local queue = {}
			SmallNotification.Route(queue, active, toast("Level up! You are now level 3"))
			SmallNotification.Route(queue, active, toast("Team Combo is over."))
			SmallNotification.Route(queue, active, toast("Rush Hour is over."))
			SmallNotification.Route(queue, active, toast("You can afford a capsule! Check the Shop."))
			SmallNotification.Route(queue, active, toast("Quest complete: Serve 5!"))
			expect(#queue).to.equal(3)
			local list = texts(queue)
			expect(list[1]).to.equal("Level up! You are now level 3")
			expect(list[2]).to.equal("Quest complete: Serve 5!")
		end)

		it("orders by tier, FIFO within a tier", function()
			local queue = {}
			SmallNotification.Route(queue, active, toast("Team Combo is over."))
			SmallNotification.Route(queue, active, toast("Quest complete: A!"))
			SmallNotification.Route(queue, active, toast("Quest complete: B!"))
			local list = texts(queue)
			expect(list[1]).to.equal("Quest complete: A!")
			expect(list[2]).to.equal("Quest complete: B!")
			expect(list[3]).to.equal("Team Combo is over.")
		end)

		it("collapses a queued Order served! into the newest one", function()
			local queue = {}
			SmallNotification.Route(queue, toast("Level up! x"), toast("Order served! +10 · Close"))
			SmallNotification.Route(queue, toast("Level up! x"), toast("Order served! +14 · Perfect"))
			expect(#queue).to.equal(1)
			expect(queue[1].Text).to.equal("Order served! +14 · Perfect")
		end)

		it("dedupes identical text, active or queued", function()
			local queue = {}
			expect(SmallNotification.Route(queue, active, toast(active.Text))).to.equal("Dropped")
			SmallNotification.Route(queue, active, toast("Break areas are open!"))
			expect(SmallNotification.Route(queue, active, toast("Break areas are open!"))).to.equal("Dropped")
			expect(#queue).to.equal(1)
		end)

		it("lets a corrective toast replace the active one and keeps a displaced level up", function()
			local queue = {}
			local levelUp = toast("Level up! You are now level 4")
			expect(SmallNotification.Route(queue, levelUp, toast("Wrong drink: Needs ice"))).to.equal("Replace")
			expect(queue[1]).to.equal(levelUp)
			expect(SmallNotification.Route({}, active, toast("Next: Add boba"))).to.equal("Replace")
		end)

		it("drops hints while busy", function()
			expect(SmallNotification.Route({}, active, { Text = "hint", _hint = true })).to.equal("Dropped")
		end)
	end)
end
