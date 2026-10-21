---
id: GAMEPLAY-MOBILE-TICKET
title: "on phones the order ticket opens for each new order, and its collapsed header still shows the order and its patience"
priority: P1
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [UI-TICKET-DAILY-MENU]
status: READY
source_commit: 098175c
---
# GAMEPLAY-MOBILE-TICKET: on phones the order ticket opens for each new order, and its collapsed header still shows the order and its patience
Model: sonnet (Mason, Part A, Studio: no; Lens, Part B, Studio: YES exclusive)   Depends on: GAMEPLAY-REVIEW T1/T2 (OBVIOUS); run AFTER UI-TICKET-DAILY-MENU Part A lands (DEC-050 moves and scales the TicketStack)   Size: S

## Goal
- On touch devices the ticket starts collapsed to its header ("Order Ticket") and stays that way until the player taps it (`OrderTicket.luau:208-209`). The recipe steps, the cup preview, the "Serve your customer!" footer and the patience bar are hidden, so a new phone player cannot read the order or its urgency.
- (a) When a NEW ticket arrives (a different `order.Id`, or a non-nil order after nil), the ticket expands. The player can still tap the header to collapse it. Desktop behaviour is unchanged (it never collapses).
- (b) While collapsed, the header text is the order label (`order.Label` for NPC tickets; "Order Ticket" when there is no string label, for example a real-player notepad order), truncated at the end. The existing 6 px patience bar (the slot-2 primitive at `:376-392`) shows directly under the header for slot 1 as well.
- Existing primitives, tokens and sizes only. No new visual.

## Verified facts
- `canCollapse = UserInputService.TouchEnabled`; `collapsed` starts as `canCollapse` (`:208-209`). The header `TextButton` toggles it (`:442-455`). The label text is `"Order Ticket"` or `"Order Ticket 2"` (`:465-472`). Items, Patience2, the recipe divider, Recipe and ReadyFooter render only when not collapsed (`:476-500`).
- `order` comes from `OrderController.CurrentOrder` (slot 1) or `Tickets[2]` (slot 2) (`:217-235`). NPC tickets carry `Id` and `Label` (SYSTEMS ticket table). Real-player orders are item lists without `Label` (`:339-351`).
- `patience` is computed per order on Heartbeat, quantised (`:259-273`). Colours: `RED` < 0.25, `GOLD_MID` < 0.5, else `GREEN` (`:384-388`).
- UI-TICKET-DAILY-MENU (Q27 A) scales the stack with UIScale and leaves `OrderTicket.luau` untouched; it assumed phones stay collapsed. This packet changes that assumption, so Part B must re-measure.

## Write scope
Part A (Mason): `src/shared/UI/Components/Core/Hud/OrderTicket.luau` only (and its story under `src/shared/UI/Stories/` if one exists; grep `OrderTicket`).
Part B (Lens): `tasks/REVIVAL-001/GAMEPLAY-MOBILE-TICKET/` (captures/, evidence.md). Studio: a temporary `StarterGui._LensPreview` ScreenGui, destroyed before finishing.
Not touched: `Hud/init.luau`, `RecipeCard.luau`, `OrderController`, any server file, `Styles.luau`.

## Steps
1. Add an effect keyed on the order identity: `local orderKey = if order ~= nil then (order.Id or order) else nil`. When `orderKey` changes to non-nil and `canCollapse`, call `setCollapsed(false)`. Do not re-expand when the same order re-renders (patience ticks, tool attribute changes).
2. Header label: `Text = if collapsed and typeof(order.Label) == "string" then order.Label elseif isSecond then "Order Ticket 2" else "Order Ticket"`; add `TextTruncate = Enum.TextTruncate.AtEnd` and keep `TextSize` 15.
3. When collapsed and `typeof(patience) == "number"`, render the existing patience-bar Frame (same geometry and colours as `secondPatience`) as `LayoutOrder = 1` for both slots. Factor the bar into one local helper used by both places (reduce duplication, no new look).
4. Gate and `rojo build`.

## Hard constraints
- Agents never run Play or TestEZ (DEC-019; Jack does). No Studio saves, no commits.
- Serve-path invariant: nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` or the `RealOrderService` payout. This lane is client UI only; it adds no server code.
- Studio-authored content (`workspace.Assets`, `Ordering System`, `ReplicatedStorage.SelectorModels`, `ReplicatedStorage.Networking`, `SoundService.SFX`) is not in the Rojo tree and is not edited.
- DEC-013 / STYLE 6.6 ticket rule: same primitives, tokens and text sizes; no new colour, radius, font, asset, animation or badge. No new literal `Color3.fromRGB` (the file's existing literal stays).
- No economy change.
- Gate (stylua only if the file has no DEC-001 drift; otherwise gate alone, no new findings): `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`, plus `rojo build default.project.json -o <path outside the repo>`.

## Part B: Lens capture (Studio: YES, exclusive; edit mode only)
Runs after Part A passes and the source is in Studio (Rojo live-sync, unsaved). Never Play or TestEZ (DEC-019); if `get_studio_state` shows Play, STOP. No saves, no script edits.
1. Freshness: djb2 (CR stripped) checksum of `Hud/OrderTicket` and `Hud/init` under `ReplicatedStorage.Shared.UI` against the repo; a mismatch means STOP, BLOCKED.
2. Mount the real `Hud` in `StarterGui._LensPreview` (as in M4-QUESTS-REDO Part B) with a stub ticket (one NPC ticket with `Label`, `PatienceEnd`, `PatienceTotal`, `Id`). Edit mode has no TouchEnabled; record that, and capture both states by mounting with `collapsed` forced through a story prop if the story supports one, else capture the desktop state and describe the collapsed one from source.
3. Captures at 844 x 390 and 1280 x 832: one ticket expanded; two tickets (slot 1 expanded, slot 2 collapsed). Measure whether the expanded ticket overlaps the jump zone (x >= 0.75, y >= 0.6), ShiftCard and CafeRating.
4. Cleanup: `_LensPreview` destroyed; child counts unchanged; nothing saved.

## Done when
- Phone: a new ticket opens expanded; a tap collapses it; collapsed shows the label and the patience bar; desktop is unchanged.
- Part B measurements recorded; if an expanded ticket overlaps a thumb zone at 844 x 390, report it (do not change layout here; Prime asks Jack).
- Gate shows no new findings; `rojo build` succeeds.

## STOP-AND-ASK
- If UI-TICKET-DAILY-MENU has not landed: BLOCKED (sequencing).
- If the expanded ticket covers the jump zone on phone: report, do not adjust Hud layout.

## Test for Jack (Play, phone or device emulator)
- First customer: the ticket shows the steps immediately; tap the header: it collapses to "Medium Custom Boba" with a coloured patience bar under it.
- Next customer: the ticket opens again by itself.
- Patience bar colour goes green, then yellow, then red in both states.
- Desktop: identical to before.
