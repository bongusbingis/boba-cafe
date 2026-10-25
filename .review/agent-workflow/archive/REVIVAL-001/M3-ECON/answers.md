# M3-ECON: Jack's answers to proposal.md §6 (2026-10-17, walked through by Prime)

Recorded in decisions.md as DEC-023 through DEC-029 as answers were resolved.

## Batch 1 (earn side): all approved as proposed
- E1 base pay: Boba 3, Coffee 2 (+1 per Iced/Sugar option), Cocoa 2, Tea 2, Pastry/Grab 1, multi-item orders sum. Replaces the M1.4e placeholders.
- E2: 9 BB/min solo is the balance anchor.
- E3, E4, E6: grade Perfect 1.0 / Close 0.5, Fast x1.5 (<50% patience), Combo +10%/Perfect cap +50%, Rescue x1.5 (<30% patience), min 1 BB. As coded.
- E5: real-player order x2 for the barista, anti-farm cap first 3 orders per customer per 10 min.
- E7: shift stars 5/10/15 BB.
- E8: Rush Hour x2 pay for 120 s at 100% Cafe Rating.
- E13: XP 10/+5 Perfect/+5 Fast per item; +10 + 5/star per shift; curve 60 + 25L + 2L^2.

## Batch 2 (sinks): E11-E12 deferred
- E11 BobaBucks capsule skip: deferred; keep the existing Robux-only Skip Hatch path for now. No BobaBucks price or purchase path is approved.
- E12 Cafe-upgrade sink: deferred; no upgrade scope or price is approved. A later proposal must define the upgrade scope, price, effect, and persistence/ownership behavior.

## Batch 3 (monetization): E14 recommendations approved
- Keep the current pack quantities. Jack approved Terra's recommended Creator Hub default prices: 50 BB = 25 R$; 150 BB = 59 R$; 500 BB = 149 R$; 1,000 BB = 249 R$; 5,000 BB = 999 R$.
- Jack will configure these prices in Creator Hub. Runtime UI must use live Marketplace product metadata, not hardcoded Robux prices. No product IDs, Creator Hub changes, or purchase/receipt wiring are authorized by this answer.

- E15 Skip Hatch Robux price: deferred; no Terra recommendation or Creator Hub/code action requested. Existing product path left untouched.

## Batch 4 (remaining M3 questions): answered / review pending
- E9: keep Rare 250 BB and Nametag 150 BB; no play-time target.
- E10: Prime recommendation requested for bulk prices and purchase wiring; pending Terra review and Jack's final choice.
- E16: add a Robux capsule purchase path; Jack configures prices in Creator Hub. PolicyService compliance is required. Terra review requested for the restricted-player alternative; SKU scope, product IDs, and safe implementation remain pending.
- E17: defer 30-minute 2× tips because direct real-customer tipping is no longer central to the current loop.
- E18: include Boba Party as a 10-minute Rush Hour; defer Creator Hub price. Cooldown/overlap behavior awaits Terra recommendation and Jack's choice.
- E19: defer tip jar.
- E20: approve defined mappings in revival-plan §6.3; defer x2/x4 multiplier values, Unlock All Pets reward, and Unlimited Stock restock effect.
- E21: approve pet tip boosts +2% / +4% / +7% / +10% by Basic / Rare / Epic / Legendary tier.
- E22: approve a group benefit concept with explicit join-group prompt, excluding tips. Exact benefit awaits Terra recommendation and Jack's choice; account for existing one-time GroupPet award.
- E23: approve +10% server-wide pay for 60 seconds at a 10-serve Team Combo chain.

## Batch 5 (Terra recommendations approved by Jack, 2026-10-17)
- **E10:** Approve 10-pack = 1,350 BB and 50-pack = 6,000 BB. Bulk rows stay unavailable until stack grant/decrement, purchase wiring, capacity handling, and reward-insertion failure handling are implemented and reviewed. Keep the 150-BB single capsule path.
- **E16:** Approve the compliance gate: no paid-random capsule purchase path ships before PolicyService restriction enforcement and numeric odds disclosure. Restricted-player alternative: free first-shift Regular capsule and deterministic Nametag option; no direct pet offers invented. Capsule acquisition provenance/currency enforcement requires a technical design review. Jack configures Creator Hub prices; IDs remain prerequisites to purchase wiring.
- **E18:** Approve 10-minute Party, 10-minute cooldown after it ends, no overlap/stacking with earned Rush/another Party, and active-Party paid receipts extend the event by 10 minutes.
- **E22:** Approve the existing one-time Ant Pet as the only non-tip group benefit, with persistent user-initiated join prompt and server-side membership recheck/claim; UI follows existing style.

