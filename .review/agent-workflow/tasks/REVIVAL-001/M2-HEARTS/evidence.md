RESULT: PASS
Changed: RealOrderService.luau (hearts prompt on pick-up, validated, once per order), ProfileTemplate.luau (Statistics.HeartsReceived/HeartsCount = 0, Jack-approved widening). Reused existing ButtonPrompt (buttons "1"-"5"), so no new dialog file; OrderController unchanged (the ready-order beam to the customer already exists via PickUpNodeVisibilityChanged isReady and is removed on pick-up).
Gate: PASS (selene new=0, stylua ok, rojo build ok) on both files.
Test for Jack: (1) real customer orders, barista serves, customer picks up -> "Rate your barista" prompt names barista with buttons 1-5; (2) tap 4 -> barista HeartsReceived +4, HeartsCount +1; (3) dismiss/timeout -> nothing added, no second prompt for same order; (4) beam appears to pick-up node when ready and vanishes on pick-up (needs place PickupBeam).
Question: OK to keep plain "1"-"5" labels (heart glyph risks font gaps)?
