# M1 + M2 test checklist for Jack (DEC-019)
Built from each evidence file's "Test for Jack" / UNVERIFIED lines. Nothing here has been Play-tested.
Setup: Rojo synced, place saved. For TestEZ: `workspace:SetAttribute("RunTests", true)` in Edit, Play, read Output, then set it back to nil.

## 0. Boot (one Play)
- [ ] Output has no "missing" warns from CustomerService, SpillService, SpillController, TrashService, UniformService, AreaController (AreaController warns only if no gates exist; that's expected).
- [ ] TestEZ: OrderService, OrderSpec, KitchenAttributes, CustomerService, ShiftService, RealOrder, CafeRating specs pass.

## 1. Spawn and world (RIG-1)
- [ ] You spawn inside the kitchen near Clear Cup (SpawnInterior1-4); the old outside spawns are off.
- [ ] Two players walk through each other (no body-blocking behind the counter, DEC-022). This needs the NPC contract present, because CustomerService sets up the groups.
- [ ] You can walk into the kitchen and behind the counter. The legacy GroupDoors walls (Kitchen/Ordering/Staff Lines) are now non-collide.

## 2. NPC customers (M1.4core, M1.4e, M1.4f, NPC-LOOK)
- [ ] Clock in → NPCs appear at Entry, follow Path, line up in Queue, step to the registers (Counter 1-5), and face the kitchen.
- [ ] NPC look: wave and greeting line on arrival; Idle anim plays; bubble shows the order and a patience bar (green → yellow → red).
- [ ] Patience pauses when nobody is clocked in; at zero the NPC leaves via Exit (no penalty).
- [ ] Ticket appears; Serve/Rescue prompt visibility works with 2 clients.
- [ ] Serve the right drink → BobaBucks go up (M1.4e). Wrong serve → Confused anim and WrongOrder line.
- [ ] Clock in/out → uniform goes on, then your original clothes come back.

## 3. Kitchen guidance and recipes (M1.5b, M1.5cd, Q14-GATES)
- [ ] Recipe card ticks update within 0.2 s of each station action; Wrong/Close states show; the card collapses on phone.
- [ ] Gold Highlight + beam on the nearest next station (never more than 2 Highlights); after 4 repeats of the same item the beam hides until you're idle 20 s.
- [ ] Settings > Staff > "Station hints" off removes highlight, beam and toasts.
- [ ] Wrong station → "Next: X" toast; picker buttons pulse gold; clocked out + station use → Clock In toast.
- [ ] Coffee: Small cup → Coffee Machine Regular (4 s hold) → serve = Perfect. Sugar then Ice (3 s) and Ice then Sugar give the same tool.

## 4. Orders (R1-FIX, M2-REALORDER, M2-HEARTS, M2-TICKET2)
- [ ] An off-menu order (smoothie) is refused; Regular/Brownie/Boba work end to end. Only launch items show in Ordering/MobileOrder/Food Menu.
- [ ] Two baristas: an occupied pickup node says "This spot is taken"; clocking out releases the claimed order.
- [ ] Re-depositing a picked-up drink → "An item is missing".
- [ ] 3 clients (2 baristas + customer): real order auto-assigns; x2 pay for the first 3 orders, then x1; customer keeps the drink; RegularOrders goes up.
- [ ] Customer pickup → "Rate your barista" prompt with buttons 1-5 that names the barista; tapping 4 → HeartsReceived +4, HeartsCount +1; only one prompt per order; you can't rate yourself. Ready-order beam shows, then clears on pickup.
- [ ] At L5 you hold 2 tickets, stacked; the overhead shows your title under your name.

## 5. Shift, progression, variants, rating (M2-SHIFT, M2-PROGRESS, M2-VARIANTS, M2-RATING)
- [ ] Fresh profile: serve 5 → shift card shows for 8 s ("Next shift starts now"); 10 more → 6 s card; "Shift k/N" shows only while clocked in.
- [ ] Serve 5 customers → XP/Level attributes change, level-up toast; L5 nametag in inventory.
- [ ] L10 profile: Karen appears (Karen look; Confused on Close; stomps out). L6: VIP gold bubble. L5: two-item orders.
- [ ] Cafe rating meter at top centre (set START = 99 to test); Rush toast/pay; meter frozen during Rush; spill XP 5.

## 6. Spills, trash, areas (SPILLS, SPILLS-CLIENT, TRASH, M2-AREAS)
- [ ] A spill appears on the seating/queue floor (Spills.Areas); mop it → sparkles, SpillsCleaned +1; walking on it trips you (anim + board).
- [ ] Each of the 6 trash cans: hold a drink, Use → Yes removes it; No keeps it; NotDisposable is refused; no tool → toast; more than 12 studs away at Yes → kept.
- [ ] Areas: once you've placed Gate parts in ReplicatedStorage.AreaLimits.BreakGates, a player under L3 is blocked and sees the sign; at L3 the gates vanish without a rejoin.

## 7. Recipe book and measure (M2-RECIPEBOOK, M1.MEASURE)
- [ ] Recipe Book lists each ORDER_POOL item; Tips tab is there.
- [ ] Analytics events fire (dashboard check, optional).

## Known accepted gaps
Patience bar hidden for orders with empty Steps; CurrencyService.Modify default reason "Shop"; recipe card shows the first item of a multi-item order.
